#!/usr/bin/env bash
# Prueba end-to-end REAL: genera un proyecto desde el template en un
# directorio temporal, instala dependencias de verdad, y corre
# `just setup && just gauntlet-full` de principio a fin -- Docker real,
# Postgres real, sin mocks ni atajos.
#
# Esto es exactamente lo que scripts/verify-template.sh deliberadamente
# NO hace -- su propio comentario dice "no que la app de ejemplo pase su
# propio gauntlet (eso requeriría Docker + red + varios minutos)". Ese
# hueco conocido cobró factura una vez: verify-template.sh pasaba sus
# cuatro checks en verde mientras `just setup` fallaba sobre Docker real
# en un proyecto recién generado (PG_PORT/COMPOSE_PROJECT_NAME nunca
# resueltos a tiempo, un wait a Postgres que no esperaba de verdad, un
# db-reset que reutilizaba estado de una corrida anterior). Este script
# es la respuesta a eso -- no una capa más de "parece que funciona".
#
# Lento a propósito (pnpm install + Docker + el gauntlet completo, varios
# minutos): no corre en cada push/PR. Ver .github/workflows/verify-e2e.yml
# (programado + disparo manual).
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SOURCE_DIR=$(mktemp -d)
PROJECT_DIR=$(mktemp -d)
ERRORS=0

cleanup() {
  if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    ( cd "$PROJECT_DIR" && docker compose down -v >/dev/null 2>&1 || true )
  fi
  rm -rf "$SOURCE_DIR" "$PROJECT_DIR"
}
trap cleanup EXIT INT TERM

for TOOL in copier just pnpm docker jq; do
  command -v "$TOOL" >/dev/null 2>&1 || {
    echo "ERROR: '$TOOL' no está instalado -- no se puede correr la verificación end-to-end. Bloqueo preventivo." >&2
    exit 1
  }
done

rsync -a --exclude='.git' --exclude='node_modules' --exclude='.env' "$REPO_ROOT/" "$SOURCE_DIR/"

echo "==> Generando proyecto de prueba end-to-end en $PROJECT_DIR..."
COPY_OUTPUT=$(copier copy "$SOURCE_DIR" "$PROJECT_DIR" \
  --data project_name="Verify E2E" \
  --data package_name="verify-e2e" \
  --data db_name="verify_e2e_dev" \
  --data github_owner="MrJuancho" \
  --trust --defaults 2>&1)
COPY_CODE=$?

if [ "$COPY_CODE" -ne 0 ]; then
  echo "ERROR: 'copier copy' falló (código $COPY_CODE):" >&2
  echo "$COPY_OUTPUT" >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Ningún archivo del proyecto generado debe tener "5432" literal SIN
# PG_PORT de por medio -- eso sería un hardcode real que ignora el
# aislamiento por worktree. Excepciones legítimas, documentadas, no
# leftovers: el fallback `${PG_PORT:-5432}` (bash) / `PG_PORT ?? '5432'`
# (TS); `docker compose port <servicio> 5432`, donde 5432 es el puerto
# FIJO interno del contenedor que ese comando necesita como argumento (no
# el mapeo al host, que sí es dinámico), nada que ver con PG_PORT; y el
# ejemplo comentado en .env.example de cómo apuntar a mano a un Postgres
# DISTINTO al de este worktree -- ahí hardcodear un puerto de ejemplo es
# justo el punto, un archivo .env no tiene forma de expandir ${PG_PORT}.
# Corre ANTES de 'pnpm install'/'just setup' a propósito: node_modules
# aún no existe, así que no hay que excluirlo del grep.
echo "==> Verificando que ningún archivo tenga '5432' sin PG_PORT de por medio..."
BAD_5432=$(grep -rn "5432" . 2>/dev/null \
  | grep -v '/\.git/' \
  | grep -v 'PG_PORT' \
  | grep -v 'port postgres 5432' \
  | grep -v '^\./\.env\.example:' \
  || true)
if [ -n "$BAD_5432" ]; then
  echo "ERROR: '5432' aparece sin PG_PORT de por medio -- posible hardcode real que rompe el aislamiento por worktree:" >&2
  echo "$BAD_5432" >&2
  ERRORS=$((ERRORS + 1))
else
  echo "✔ Todo uso de '5432' está atado a PG_PORT (o es el puerto interno fijo de 'docker compose port')."
fi

echo "==> Corriendo 'just setup' de verdad (Docker real, Postgres real)..."
SETUP_LOG=$(mktemp)
if just setup >"$SETUP_LOG" 2>&1; then
  echo "✔ 'just setup' terminó en verde."
else
  echo "ERROR: 'just setup' falló:" >&2
  tail -n 100 "$SETUP_LOG" >&2
  ERRORS=$((ERRORS + 1))
fi
rm -f "$SETUP_LOG"

echo "==> Verificando que .env.local existe tras 'just setup'..."
if [ -f .env.local ]; then
  # shellcheck disable=SC1091
  set -a
  source .env.local
  set +a
  if [ -n "${PG_PORT:-}" ] && [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
    echo "✔ .env.local existe: PG_PORT=${PG_PORT}, COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}."
  else
    echo "ERROR: .env.local existe pero PG_PORT o COMPOSE_PROJECT_NAME están vacíos." >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "ERROR: .env.local NO existe tras 'just setup' -- worktree-env.sh no corrió, o no como primer paso." >&2
  ERRORS=$((ERRORS + 1))
fi

echo "==> Verificando que el contenedor de Postgres lleva el hash de COMPOSE_PROJECT_NAME en su nombre..."
if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
  RUNNING=$(docker ps --filter "name=${COMPOSE_PROJECT_NAME}-postgres" --format '{{.Names}}')
  if [ -n "$RUNNING" ]; then
    echo "✔ Contenedor '$RUNNING' corriendo -- lleva COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME} en el nombre."
  else
    echo "ERROR: no se encontró un contenedor Postgres corriendo cuyo nombre incluya COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}." >&2
    docker ps -a --format '  {{.Names}}' >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "ERROR: COMPOSE_PROJECT_NAME no está definido -- no se puede verificar el nombre del contenedor." >&2
  ERRORS=$((ERRORS + 1))
fi

echo "==> Corriendo 'just gauntlet-full' de verdad..."
GAUNTLET_LOG=$(mktemp)
if just gauntlet-full >"$GAUNTLET_LOG" 2>&1; then
  echo "✔ 'just gauntlet-full' terminó en verde."
else
  echo "ERROR: 'just gauntlet-full' falló:" >&2
  tail -n 150 "$GAUNTLET_LOG" >&2
  ERRORS=$((ERRORS + 1))
fi
rm -f "$GAUNTLET_LOG"

if [ "$ERRORS" -gt 0 ]; then
  echo "✖ Verificación end-to-end falló ($ERRORS problema(s))." >&2
  exit 1
fi

echo "✔ El proyecto generado arranca de verdad: 'just setup && just gauntlet-full' en verde, sobre Docker real."
