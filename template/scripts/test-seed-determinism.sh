#!/usr/bin/env bash
set -euo pipefail

TEST_DB="_gauntlet_seed_test"
DUMP1="/tmp/seed_run1.sql"
DUMP2="/tmp/seed_run2.sql"
HASH1="/tmp/seed_run1.hash"
HASH2="/tmp/seed_run2.hash"

cleanup() {
  rm -f "$DUMP1" "$DUMP2" "$HASH1" "$HASH2"
  docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${TEST_DB};" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

run_seed_cycle() {
  local dump_file="$1"
  local hash_file="$2"

  # 1. Recrear base de datos limpia
  docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${TEST_DB};" >/dev/null
  docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE ${TEST_DB};" >/dev/null

  # 2. Correr migraciones
  DATABASE_URL="postgres://postgres:postgres@127.0.0.1:${PG_PORT:-5432}/${TEST_DB}" pnpm exec tsx src/infra/db/migrate.ts >/dev/null

  # 3. Ejecutar seed
  DATABASE_URL="postgres://postgres:postgres@127.0.0.1:${PG_PORT:-5432}/${TEST_DB}" pnpm exec tsx src/infra/db/seed.ts >/dev/null

  # 4. Volcar datos (solo sentencias INSERT, ordenadas alfabéticamente)
  docker compose exec -T postgres pg_dump -U postgres -d "${TEST_DB}" \
    --data-only \
    --inserts \
    --exclude-table="*drizzle*" | grep -E '^INSERT INTO' | sort > "$dump_file"

  # 5. Generar firma SHA-256
  sha256sum "$dump_file" | awk '{print $1}' > "$hash_file"
}

echo "Gate 7: Ejecutando ciclo 1 de seed..."
run_seed_cycle "$DUMP1" "$HASH1"
H1=$(cat "$HASH1")
echo "Firma Ciclo 1: $H1"

echo "Gate 7: Ejecutando ciclo 2 de seed..."
run_seed_cycle "$DUMP2" "$HASH2"
H2=$(cat "$HASH2")
echo "Firma Ciclo 2: $H2"

if [ "$H1" != "$H2" ]; then
  echo "ERROR Gate 7: Los seeds no son deterministas. Las firmas difieren." >&2
  diff -u "$DUMP1" "$DUMP2" >&2 || true
  exit 1
fi

echo "Gate 7 OK: Seeds 100% reproducibles y deterministas."
