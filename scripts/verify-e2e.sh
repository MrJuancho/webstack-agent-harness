#!/usr/bin/env bash
# Prueba end-to-end REAL: toma la plantilla EXACTAMENTE como la tomaría
# un usuario real -- clonando el remoto, sin --vcs-ref -- genera un
# proyecto en un directorio temporal, instala dependencias de verdad, y
# corre `just setup && just gauntlet-full` de principio a fin. Docker
# real, Postgres real, red real, sin mocks ni atajos.
#
# "Sin --vcs-ref" es deliberado, no un descuido: Copier usa el tag más
# reciente por defecto si el repo tiene tags, y no el checkout local de
# quien corre esto -- probar contra un rsync del working tree (la versión
# anterior de este script) no puede atrapar eso. Confirmado con un
# incidente real: dos tags viejos en este repo hacían que el comando de
# Quick Start del README sirviera un snapshot de ~30 commits de
# antigüedad a cualquiera, sin ningún aviso -- ver docs/progress.md.
# Borrar esos tags arregla el síntoma hoy, no el mecanismo: el día que
# este repo vuelva a tener tags (el uso maduro y deseable de una
# plantilla versionada), la misma trampa vuelve a estar armada. Por eso
# este script también afirma que el `_commit` que terminó en
# `.copier-answers.yml` coincide con el HEAD remoto real -- reusando el
# mismo check de `doctor.sh` (DOCTOR_STRICT_TEMPLATE_FRESHNESS=1) que un
# usuario real vería como advertencia, no duplicando la lógica acá.
#
# Lento a propósito (red + pnpm install + Docker + el gauntlet completo,
# varios minutos): no corre en cada push/PR. Ver
# .github/workflows/verify-e2e.yml (programado + disparo manual).
set -uo pipefail

# URL canónica y pública, la misma que el README documenta en su comando
# de Quick Start -- a propósito NO derivada de `git remote get-url
# origin`: ese remoto refleja cómo ESTE checkout particular está
# configurado (podría ser SSH, un fork, un mirror), no lo que un usuario
# real tipea siguiendo el README. Confirmado a mano: en este entorno
# `origin` es SSH y `git ls-remote` sobre SSH se queda colgado sin
# credenciales -- exactamente el tipo de falso negativo que probar la URL
# canónica evita.
TEMPLATE_URL="https://github.com/MrJuancho/webstack-agent-harness.git"
PROJECT_DIR=$(mktemp -d)
ERRORS=0

cleanup() {
  if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    ( cd "$PROJECT_DIR" && docker compose down -v >/dev/null 2>&1 || true )
  fi
  rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT INT TERM

for TOOL in copier just pnpm docker jq git; do
  command -v "$TOOL" >/dev/null 2>&1 || {
    echo "ERROR: '$TOOL' no está instalado -- no se puede correr la verificación end-to-end. Bloqueo preventivo." >&2
    exit 1
  }
done

echo "==> Consultando el HEAD remoto real de $TEMPLATE_URL antes de generar..."
# `awk '$2 == "HEAD"'`, no un simple `{print $1}`: `git ls-remote <repo>
# HEAD` matchea como patrón cualquier ref que TERMINE en "HEAD" (ej.
# refs/remotes/origin/HEAD si el remoto trae refs de tracking), no solo
# el ref exacto -- confirmado a mano contra un path local. Exigir la
# coincidencia exacta es gratis y cierra ese caso raro también acá.
EXPECTED_HEAD=$(timeout 30 git ls-remote "$TEMPLATE_URL" HEAD 2>/dev/null | awk '$2 == "HEAD" {print $1; exit}' || true)
if [ -z "$EXPECTED_HEAD" ]; then
  echo "ERROR: no se pudo consultar el HEAD remoto de $TEMPLATE_URL (¿sin red?). Bloqueo preventivo." >&2
  exit 1
fi
echo "    HEAD remoto esperado: $EXPECTED_HEAD"

echo "==> Generando proyecto de prueba end-to-end en $PROJECT_DIR (clonando $TEMPLATE_URL, SIN --vcs-ref -- igual que un usuario real)..."
COPY_OUTPUT=$(copier copy "$TEMPLATE_URL" "$PROJECT_DIR" \
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

echo "==> Verificando que el proyecto generado viene del HEAD remoto esperado..."
if [ -f .copier-answers.yml ]; then
  ACTUAL_COMMIT=$(grep -E '^_commit:' .copier-answers.yml | head -1 | sed -E "s/^_commit:[[:space:]]*//; s/^['\"]//; s/['\"]\$//")
  case "$EXPECTED_HEAD" in
    "$ACTUAL_COMMIT"*)
      echo "✔ El proyecto generado viene del HEAD remoto esperado (_commit=$ACTUAL_COMMIT)."
      ;;
    *)
      echo "ERROR: el proyecto generado viene de _commit=$ACTUAL_COMMIT, pero el HEAD remoto real es $EXPECTED_HEAD -- 'copier copy' sin --vcs-ref no está sirviendo HEAD (¿volvió a haber un tag?)." >&2
      ERRORS=$((ERRORS + 1))
      ;;
  esac
else
  echo "ERROR: el proyecto generado no tiene .copier-answers.yml -- 'copier update' quedaría roto para cualquiera que lo use." >&2
  ERRORS=$((ERRORS + 1))
fi

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

echo "==> Corriendo 'just setup' de verdad (Docker real, Postgres real, doctor en modo estricto)..."
SETUP_LOG=$(mktemp)
if DOCTOR_STRICT_TEMPLATE_FRESHNESS=1 just setup >"$SETUP_LOG" 2>&1; then
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
