#!/usr/bin/env bash
set -euo pipefail

MIGRATIONS_DIR="src/infra/db/migrations"
TEST_DB="_gauntlet_migrate_rev_test"
DUMP_BEFORE="/tmp/schema_before.sql"
DUMP_AFTER="/tmp/schema_after.sql"

cleanup() {
  rm -f "$DUMP_BEFORE" "$DUMP_AFTER"
  docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${TEST_DB};" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM
cleanup

echo "Gate 1: Comprobando existencia de scripts de reversión (.down.sql)..."
MISSING_DOWN=0
for up_file in $(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" ! -name "*.down.sql" | sort); do
  down_file="${up_file%.sql}.down.sql"
  if [ ! -f "$down_file" ]; then
    echo "ERROR Gate 1: Falta migración de reversión para: $up_file" >&2
    MISSING_DOWN=1
  fi
done

if [ "$MISSING_DOWN" -ne 0 ]; then
  exit 1
fi

# Inicializar base de datos efímera
docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${TEST_DB};" >/dev/null
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE ${TEST_DB};" >/dev/null

# Helper para volcar esquema filtrando comentarios y metacomandos (\restrict, \unrestrict, etc.)
dump_clean_schema() {
  local target_file="$1"
  docker compose exec -T postgres pg_dump -U postgres -d "${TEST_DB}" --schema-only --no-owner --no-privileges \
    | grep -vE '^(--|\\)' \
    | sed '/^$/d' \
    | sort > "$target_file"
}

# Volcado del esquema base limpio
dump_clean_schema "$DUMP_BEFORE"

# 1. Aplicar migraciones UP
echo "Gate 1: Aplicando migraciones UP..."
for up_file in $(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" ! -name "*.down.sql" | sort); do
  docker compose exec -T postgres psql -U postgres -d "${TEST_DB}" -v ON_ERROR_STOP=1 < "$up_file" >/dev/null
done

# 2. Aplicar migraciones DOWN (orden descendente)
echo "Gate 1: Aplicando migraciones DOWN en orden inverso..."
for down_file in $(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.down.sql" | sort -r); do
  docker compose exec -T postgres psql -U postgres -d "${TEST_DB}" -v ON_ERROR_STOP=1 < "$down_file" >/dev/null
done

# Volcado del esquema post-rollback
dump_clean_schema "$DUMP_AFTER"

# 3. Comprobar que no queden residuos
echo "Gate 1: Verificando que el rollback no dejó residuos DDL..."
if ! diff -u "$DUMP_BEFORE" "$DUMP_AFTER"; then
  echo "ERROR Gate 1: El rollback dejó residuos en el esquema de la base de datos." >&2
  exit 1
fi

# 4. Re-aplicar UP para garantizar idempotencia
echo "Gate 1: Re-aplicando migraciones UP para asegurar re-ejecución limpia..."
for up_file in $(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*.sql" ! -name "*.down.sql" | sort); do
  docker compose exec -T postgres psql -U postgres -d "${TEST_DB}" -v ON_ERROR_STOP=1 < "$up_file" >/dev/null
done

echo "Gate 1 OK: Todas las migraciones son reversibles e idempotentes."
