#!/usr/bin/env bash
# Prueba la imagen de producción (Dockerfile) de verdad: la construye y la
# corre. Un Dockerfile que nadie ejecuta se rompe en silencio con el
# primer cambio de estructura -- y se descubre el día del despliegue.
#
# Afirma que la imagen:
#   1. se niega a arrancar sin configuración, nombrando lo que falta;
#   2. arranca con configuración válida y responde /health;
#   3. corre con un usuario sin privilegios;
#   4. corre las migraciones compiladas contra el Postgres de este worktree;
#   5. se apaga de forma ordenada con SIGTERM (exit 0, no 137/143).
set -euo pipefail

DB_NAME="${1:?uso: test-docker-image.sh <db_name>}"
IMAGE="gauntlet-image-check:${COMPOSE_PROJECT_NAME:-local}"
CONTAINER="gauntlet-image-check-${COMPOSE_PROJECT_NAME:-local}"
# Solo para esta prueba: un secreto descartable del largo mínimo.
TEST_SECRET="image-check-secret-image-check-secret"
DATABASE_URL_FOR_IMAGE="postgres://postgres:postgres@127.0.0.1:${PG_PORT:-5432}/${DB_NAME}"
# Puerto del host derivado de PG_PORT (único por worktree, ver
# scripts/worktree-env.sh), para que dos worktrees no choquen acá.
IMAGE_PORT=$(( ${PG_PORT:-5432} + 10000 ))

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
cleanup

echo "Imagen: construyendo ${IMAGE}..."
docker build -q -t "$IMAGE" . >/dev/null

echo "Imagen: sin configuración debe negarse a arrancar..."
set +e
NO_CONFIG_OUTPUT=$(docker run --rm "$IMAGE" 2>&1)
NO_CONFIG_CODE=$?
set -e
if [ "$NO_CONFIG_CODE" -eq 0 ]; then
  echo "ERROR imagen: arrancó (exit 0) sin JWT_SECRET ni DATABASE_URL." >&2
  exit 1
fi
for REQUIRED in JWT_SECRET DATABASE_URL; do
  if ! printf '%s' "$NO_CONFIG_OUTPUT" | grep -q "$REQUIRED"; then
    echo "ERROR imagen: falló sin configuración (exit $NO_CONFIG_CODE) pero el mensaje no nombra $REQUIRED:" >&2
    printf '%s\n' "$NO_CONFIG_OUTPUT" >&2
    exit 1
  fi
done

echo "Imagen: arrancando con configuración válida..."
docker run -d --name "$CONTAINER" --network host \
  -e JWT_SECRET="$TEST_SECRET" \
  -e DATABASE_URL="$DATABASE_URL_FOR_IMAGE" \
  -e PORT="$IMAGE_PORT" -e HOST=127.0.0.1 \
  "$IMAGE" >/dev/null

READY=0
for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:${IMAGE_PORT}/health" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 0.25
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR imagen: el contenedor no respondió /health en 10s. Logs:" >&2
  docker logs "$CONTAINER" >&2 || true
  exit 1
fi

CONTAINER_UID=$(docker exec "$CONTAINER" id -u)
if [ "$CONTAINER_UID" = "0" ]; then
  echo "ERROR imagen: el proceso corre como root (uid 0)." >&2
  exit 1
fi

echo "Imagen: corriendo las migraciones compiladas..."
docker run --rm --network host -e DATABASE_URL="$DATABASE_URL_FOR_IMAGE" \
  "$IMAGE" node dist/infra/db/migrate.js

echo "Imagen: apagado ordenado con SIGTERM..."
docker stop -t 15 "$CONTAINER" >/dev/null
# `docker wait` sobre un contenedor ya detenido imprime su código de salida.
EXIT_CODE=$(docker wait "$CONTAINER")
if [ "$EXIT_CODE" != "0" ]; then
  echo "ERROR imagen: tras SIGTERM el contenedor salió con código $EXIT_CODE (se esperaba 0 -- apagado ordenado). Logs:" >&2
  docker logs "$CONTAINER" >&2 || true
  exit 1
fi
if ! docker logs "$CONTAINER" 2>&1 | grep -q "Shutdown requested"; then
  echo "ERROR imagen: salió con 0 pero no registró el apagado ordenado en sus logs." >&2
  docker logs "$CONTAINER" >&2 || true
  exit 1
fi

echo "✔ Imagen OK: falla cerrado sin configuración, arranca, corre sin root (uid $CONTAINER_UID), migra y se apaga de forma ordenada."
