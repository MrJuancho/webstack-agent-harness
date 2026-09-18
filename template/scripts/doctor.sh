#!/usr/bin/env bash
set -euo pipefail

echo "==> Verificando dependencias del arnés (Fail-Closed Doctor)..."

ERRORS=0

check_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  ✔ $name: $(command -v "$cmd")"
  else
    echo "  ✖ $name: NO ENCONTRADO ($cmd)" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. Herramientas base
check_cmd "Node.js (>=22)" "node"
check_cmd "pnpm" "pnpm"
check_cmd "Docker" "docker"
check_cmd "Docker Compose" "docker"
check_cmd "Gitleaks (Gate 8)" "gitleaks"
check_cmd "jq (Procesador JSON)" "jq"
check_cmd "curl" "curl"
check_cmd "sha256sum" "sha256sum"
# pg_isready (cliente de PostgreSQL, paquete postgresql-client): lo usa
# `just db-up` para esperar de verdad a que Postgres responda en el host
# antes de migrar -- sin esto, `db-up` falla con "command not found" en
# vez de con un mensaje que diga qué instalar.
check_cmd "pg_isready (postgresql-client)" "pg_isready"

# 2. Aislamiento de Postgres por worktree (PG_PORT / COMPOSE_PROJECT_NAME)
#
# .env.local es la única fuente de verdad (scripts/worktree-env.sh la
# deriva del path de este worktree) -- se carga acá de forma defensiva en
# vez de depender de que `just` ya la haya exportado, porque este script
# también debe poder correr solo (`bash scripts/doctor.sh`).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$REPO_ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.env.local"
  set +a
else
  # Fail-closed real, no una advertencia decorativa: sin .env.local no hay
  # PG_PORT/COMPOSE_PROJECT_NAME, así que todo lo que dependa de ellos
  # (docker-compose.yml, drizzle.config.ts, el cliente de infra/db) cae de
  # vuelta a defaults hardcodeados -- exactamente el escenario de colisión
  # entre worktrees que scripts/worktree-env.sh existe para prevenir. Un
  # "⚠" acá era la única señal de que el entorno no estaba listo, y no
  # detenía nada: `just setup` seguía de largo hacia `just gauntlet` sobre
  # un entorno a medio configurar.
  echo "  ✖ .env.local no existe -- ejecutar 'bash scripts/worktree-env.sh' (o 'just setup', que ya lo hace primero)" >&2
  ERRORS=$((ERRORS + 1))
fi

if command -v docker >/dev/null 2>&1 && [ -n "${COMPOSE_PROJECT_NAME:-}" ] && [ -n "${PG_PORT:-}" ]; then
  RUNNING_PORT=$(docker compose -p "$COMPOSE_PROJECT_NAME" port postgres 5432 2>/dev/null | awk -F: '{print $NF}' || true)

  if [ "$RUNNING_PORT" = "$PG_PORT" ]; then
    if docker compose -p "$COMPOSE_PROJECT_NAME" exec -T postgres pg_isready >/dev/null 2>&1; then
      echo "  ✔ PostgreSQL 16 (tmpfs): Conectado y listo en PG_PORT=${PG_PORT} (proyecto ${COMPOSE_PROJECT_NAME})"
    else
      echo "  ⚠ PostgreSQL 16 (tmpfs): Contenedor de este worktree existe pero no responde aún"
    fi
  elif (echo >"/dev/tcp/127.0.0.1/${PG_PORT}") 2>/dev/null; then
    echo "  ✖ PG_PORT ${PG_PORT}: ocupado por OTRO proceso/worktree, no por el contenedor de ${COMPOSE_PROJECT_NAME}." >&2
    echo "    Define PG_PORT=<otro-puerto> en el entorno antes de 'bash scripts/worktree-env.sh' para forzar otro valor, o libera el puerto." >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "  ⚠ PostgreSQL 16 (tmpfs): PG_PORT=${PG_PORT} libre pero contenedor inactivo (ejecutar 'just db-up')"
  fi
fi

# 3. Procedencia de la plantilla (.copier-answers.yml): un mismatch acá
# NO es necesariamente un error -- un proyecto puede estar clavado a un
# tag viejo a propósito, y eso es justo el uso maduro que se espera de
# una plantilla versionada. Por defecto esto solo informa (⚠). Existe
# porque un incidente real fue un fallo de Docker desconcertante sin
# ninguna pista de que el proyecto venía de un snapshot de la plantilla
# de ~30 commits de antigüedad -- este check convierte eso en un mensaje
# directo. Con DOCTOR_STRICT_TEMPLATE_FRESHNESS=1 (lo que usa
# scripts/verify-e2e.sh para afirmar que lo que un usuario real
# descargaría hoy sí coincide con el HEAD real de la plantilla) se vuelve
# bloqueante (✖).
# En modo estricto, cualquier cosa que no sea una confirmación POSITIVA
# de que está al día (archivo ausente, campos ausentes, sin red) también
# es bloqueante -- fail-closed de verdad. En modo normal, esas mismas
# situaciones ambiguas son solo informativas: un hipo de red no debería
# bloquear un `just doctor` cualquiera durante el desarrollo local.
report_provenance() {
  local level="$1" msg="$2"
  if [ "$level" = "warn-or-fail" ]; then
    if [ "${DOCTOR_STRICT_TEMPLATE_FRESHNESS:-0}" = "1" ]; then
      echo "  ✖ $msg" >&2
      ERRORS=$((ERRORS + 1))
    else
      echo "  ⚠ $msg"
    fi
  else
    echo "  $msg"
  fi
}

ANSWERS_FILE="$REPO_ROOT/.copier-answers.yml"
if [ -f "$ANSWERS_FILE" ]; then
  ANSWERS_COMMIT=$(grep -E '^_commit:' "$ANSWERS_FILE" | head -1 | sed -E "s/^_commit:[[:space:]]*//; s/^['\"]//; s/['\"]\$//")
  ANSWERS_SRC=$(grep -E '^_src_path:' "$ANSWERS_FILE" | head -1 | sed -E "s/^_src_path:[[:space:]]*//; s/^['\"]//; s/['\"]\$//")
  if [ -z "$ANSWERS_COMMIT" ] || [ -z "$ANSWERS_SRC" ]; then
    report_provenance warn-or-fail ".copier-answers.yml existe pero no tiene _commit/_src_path -- no se puede verificar la procedencia."
  else
    # `awk '$2 == "HEAD"'` (no basta con pedirle "HEAD" a ls-remote): contra
    # un remoto que además trae refs de tracking locales (ej. probando a
    # mano contra un path local con refs/remotes/origin/HEAD) "HEAD" matchea
    # como patrón cualquier ref que TERMINE en HEAD, no solo el ref exacto
    # -- confirmado a mano, devolvía dos líneas. Contra una URL real esto no
    # pasa, pero exigir la coincidencia exacta es gratis y evita el caso raro.
    REMOTE_HEAD=$(timeout 8 git ls-remote "$ANSWERS_SRC" HEAD 2>/dev/null | awk '$2 == "HEAD" {print $1; exit}' || true)
    if [ -z "$REMOTE_HEAD" ]; then
      report_provenance warn-or-fail "no se pudo consultar el HEAD remoto de la plantilla ($ANSWERS_SRC) -- ¿sin red? No se pudo confirmar la procedencia."
    else
      case "$REMOTE_HEAD" in
        "$ANSWERS_COMMIT"*)
          report_provenance ok "✔ Plantilla al día con el HEAD remoto (_commit=$ANSWERS_COMMIT)."
          ;;
        *)
          report_provenance warn-or-fail "plantilla desactualizada: este proyecto viene de _commit=$ANSWERS_COMMIT; el HEAD remoto de la plantilla ($ANSWERS_SRC) es $REMOTE_HEAD. Si no fue a propósito, correr 'copier update'."
          ;;
      esac
    fi
  fi
else
  report_provenance warn-or-fail "no se encontró .copier-answers.yml -- no se puede verificar de qué versión de la plantilla salió este proyecto."
fi

# 4. Validar versión de Node.js
NODE_MAJOR=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  ✖ Node.js versión incompatible: Se requiere >= 22 (Detectada: $(node -v))" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "" >&2
  echo "ERROR: Fallaron $ERRORS verificaciones del sistema. El arnés se niega a operar." >&2
  exit 1
fi

echo "✔ Todas las dependencias están operativas."
