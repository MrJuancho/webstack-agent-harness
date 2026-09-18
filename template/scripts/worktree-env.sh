#!/usr/bin/env bash
# Deriva, de forma determinista y sin coordinación externa, un PG_PORT y un
# COMPOSE_PROJECT_NAME únicos por worktree -- para que N worktrees del mismo
# proyecto puedan correr `just gauntlet` en paralelo sin chocar en el puerto
# del host de Postgres ni en los nombres de recursos de Docker Compose
# (contenedores, redes, volúmenes).
#
# Fuente del namespacing: el path absoluto del worktree (`git rev-parse
# --show-toplevel`). Dos worktrees son dos paths distintos, así que dos
# hashes distintos, sin necesidad de un archivo de estado compartido ni de
# reservar puertos contra un registro central.
#
# Salida: escribe PG_PORT y COMPOSE_PROJECT_NAME en .env.local (gitignored,
# vía el patrón `.env.*` de .gitignore) en la raíz del worktree. Esa es la
# única fuente de verdad que debe leer cualquier cosa que arme un
# DATABASE_URL o invoque `docker compose` -- `just` la carga automáticamente
# (`set dotenv-filename := ".env.local"` en el justfile) para cada receta, y
# el código TypeScript la lee vía `dotenv` en tiempo de arranque.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: 'jq' no está instalado -- no se puede leer package_name de package.json." >&2
  exit 1
}

PACKAGE_NAME="$(jq -r '.name' package.json)"
if [ -z "$PACKAGE_NAME" ] || [ "$PACKAGE_NAME" = "null" ]; then
  echo "ERROR: package.json no tiene un campo 'name' válido." >&2
  exit 1
fi

HASH="$(printf '%s' "$REPO_ROOT" | sha256sum | cut -c1-8)"

# Escape hatch: si PG_PORT ya viene definido en el entorno (por ejemplo, un
# agente o un CI que necesita un valor específico), se respeta tal cual en
# vez de recalcularlo.
if [ -n "${PG_PORT:-}" ]; then
  echo "==> PG_PORT ya definido en el entorno (${PG_PORT}) -- se respeta sin recalcular."
else
  PG_PORT=$((20000 + (16#$HASH % 10000)))
fi

COMPOSE_PROJECT_NAME="${PACKAGE_NAME}-${HASH}"

cat > .env.local <<EOF
# Generado por scripts/worktree-env.sh -- NO editar a mano.
# \`just setup\` (o \`bash scripts/worktree-env.sh\` directamente) lo
# regenera a partir del path de este worktree. Ver el comentario al inicio
# de ese script para el porqué.
PG_PORT=${PG_PORT}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
EOF

echo "✔ .env.local escrito para el worktree ${REPO_ROOT}:"
echo "    PG_PORT=${PG_PORT}"
echo "    COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
