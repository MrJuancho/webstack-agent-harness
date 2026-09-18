#!/usr/bin/env bash
# Verifica el mecanismo del template en sí: corre un `copier copy` real
# sobre el estado actual del working tree (incluyendo cambios sin
# commitear) y falla si el resultado tiene defectos ya conocidos en este
# repo:
#
# NOTA sobre por qué se copia a un directorio SIN `.git` primero: apuntar
# `copier copy` directamente a este repo (que sí tiene `.git`) hace que
# Copier resuelva `copier.yml` y su contenido contra el último commit /
# tag, no contra el working tree -- confirmado con una prueba real (una
# tarea `_tasks` marcador que nunca se ejecutó estando sin commitear, y
# volvió a funcionar recién al commitear). Copiar primero a un directorio
# git-free evita esa ambigüedad por completo: sin `.git`, Copier solo ve
# los archivos tal como están en disco, dirty o no.
#   1. `copier copy` no termina en verde (sintaxis Jinja rota, `_tasks`
#      que falla, variable sin definir).
#   2. No quedó inicializado `.git/` en el proyecto generado (regresión
#      del hallazgo de ADR-0003: sin esto, `just install-hooks` falla en
#      cualquier proyecto recién generado).
#   3. Quedan marcadores Jinja sin renderizar (`{{`) en cualquier archivo
#      de salida -- typo de variable, o un archivo que necesitaba `.jinja`
#      y no lo tiene.
#   4. Quedan referencias literales a "webstack" en la salida -- el mismo
#      tipo de fuga que ADR-0003 encontró en dos scripts de gates.
#
# No requiere Docker ni `pnpm install`: verifica el mecanismo de plantilla,
# no que la app de ejemplo pase su propio gauntlet (eso requeriría Docker +
# red + varios minutos, demasiado caro para correr en cada turno de agente
# o cada commit). Deliberadamente más barato que un `just gauntlet` real --
# ver docs/progress.md para el estado de la suite de meta-tests completa
# que sí lo haría.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SOURCE_DIR=$(mktemp -d)
SCRATCH_DIR=$(mktemp -d)
WORKTREE_A_DIR=$(mktemp -d)
WORKTREE_B_DIR=$(mktemp -d)
ERRORS=0

cleanup() {
  rm -rf "$SOURCE_DIR" "$SCRATCH_DIR" "$WORKTREE_A_DIR" "$WORKTREE_B_DIR"
}
trap cleanup EXIT INT TERM

command -v copier >/dev/null 2>&1 || {
  echo "ERROR: 'copier' no está instalado -- no se puede verificar el template. Bloqueo preventivo." >&2
  exit 1
}

rsync -a --exclude='.git' --exclude='node_modules' --exclude='.env' "$REPO_ROOT/" "$SOURCE_DIR/"

echo "==> Verificando el template con un copier copy real (estado actual del working tree)..."
COPY_OUTPUT=$(copier copy "$SOURCE_DIR" "$SCRATCH_DIR" \
  --data project_name="Verify Template" \
  --data package_name="verify-template" \
  --data db_name="verify_template_dev" \
  --data github_owner="MrJuancho" \
  --trust --defaults 2>&1)
COPY_CODE=$?

if [ "$COPY_CODE" -ne 0 ]; then
  echo "ERROR: 'copier copy' falló (código $COPY_CODE):" >&2
  echo "$COPY_OUTPUT" >&2
  exit 1
fi

if [ ! -d "$SCRATCH_DIR/.git" ]; then
  echo "ERROR: el proyecto generado no tiene .git/ -- regresión del hallazgo de ADR-0003 (git init en _tasks)." >&2
  ERRORS=$((ERRORS + 1))
fi

# Exclusiones conocidas y legítimas, no leftovers:
#   - justfile: sintaxis propia de `just` para parámetros de receta
#     ({{BRANCH}}), nunca pasa por Jinja (ver ADR-0003).
#   - .github/workflows/*.yml: sintaxis de expresiones de GitHub Actions
#     (${{ secrets.* }}), no relacionada con Jinja.
#   - .specify/workflows/**: sintaxis de plantillas propia de spec-kit.
#   - docs/spec.pdf: binario; coincidencias son bytes incidentales, no texto.
LEFTOVER_JINJA=$(grep -rIl '{{' "$SCRATCH_DIR" 2>/dev/null \
  | grep -v '/\.git/' \
  | grep -v '/justfile$' \
  | grep -v '/\.github/workflows/' \
  | grep -v '/\.specify/workflows/' \
  | grep -v '/docs/spec\.pdf$' \
  || true)
if [ -n "$LEFTOVER_JINJA" ]; then
  echo "ERROR: quedaron marcadores Jinja '{{' sin renderizar en:" >&2
  echo "$LEFTOVER_JINJA" >&2
  ERRORS=$((ERRORS + 1))
fi

# AGENTS.md/README.md mencionan "webstack-agent-harness" a propósito (el
# link de atribución al template) -- cualquier OTRA aparición sí es un
# leftover real (nombres de recetas/scripts que deberían haberse
# generalizado, como los que encontró ADR-0003).
LEFTOVER_WEBSTACK=$(grep -rli "webstack" "$SCRATCH_DIR" 2>/dev/null \
  | grep -v '/\.git/' \
  | grep -v '/AGENTS\.md$' \
  | grep -v '/README\.md$' \
  || true)
if [ -n "$LEFTOVER_WEBSTACK" ]; then
  echo "ERROR: quedaron referencias literales a 'webstack' en el proyecto generado:" >&2
  echo "$LEFTOVER_WEBSTACK" >&2
  ERRORS=$((ERRORS + 1))
fi

# Aislamiento de Postgres entre worktrees (scripts/worktree-env.sh): genera
# el MISMO proyecto (mismo package_name) dos veces, en dos directorios
# distintos -- simulando dos `git worktree` del mismo repo generado -- y
# afirma que cada uno deriva un PG_PORT y un COMPOSE_PROJECT_NAME propios.
# Sin esto, dos worktrees del mismo proyecto chocan en el puerto del host
# de Postgres y en los nombres de recursos de Docker Compose.
if command -v jq >/dev/null 2>&1; then
  echo "==> Verificando aislamiento de Postgres entre worktrees (scripts/worktree-env.sh)..."

  for WT_DIR in "$WORKTREE_A_DIR" "$WORKTREE_B_DIR"; do
    rm -rf "$WT_DIR"
    WT_COPY_OUTPUT=$(copier copy "$SOURCE_DIR" "$WT_DIR" \
      --data project_name="Verify Worktree" \
      --data package_name="verify-worktree" \
      --data db_name="verify_worktree_dev" \
      --data github_owner="MrJuancho" \
      --trust --defaults 2>&1)
    WT_COPY_CODE=$?
    if [ "$WT_COPY_CODE" -ne 0 ]; then
      echo "ERROR: 'copier copy' falló generando el worktree de prueba en $WT_DIR (código $WT_COPY_CODE):" >&2
      echo "$WT_COPY_OUTPUT" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
    ( cd "$WT_DIR" && bash scripts/worktree-env.sh ) >/dev/null 2>&1
  done

  if [ -f "$WORKTREE_A_DIR/.env.local" ] && [ -f "$WORKTREE_B_DIR/.env.local" ]; then
    # shellcheck disable=SC1090
    PG_PORT_A=$(. "$WORKTREE_A_DIR/.env.local" 2>/dev/null; echo "$PG_PORT")
    PROJECT_A=$(. "$WORKTREE_A_DIR/.env.local" 2>/dev/null; echo "$COMPOSE_PROJECT_NAME")
    PG_PORT_B=$(. "$WORKTREE_B_DIR/.env.local" 2>/dev/null; echo "$PG_PORT")
    PROJECT_B=$(. "$WORKTREE_B_DIR/.env.local" 2>/dev/null; echo "$COMPOSE_PROJECT_NAME")

    if [ -z "$PG_PORT_A" ] || [ -z "$PROJECT_A" ] || [ -z "$PG_PORT_B" ] || [ -z "$PROJECT_B" ]; then
      echo "ERROR: worktree-env.sh no escribió PG_PORT/COMPOSE_PROJECT_NAME en uno de los dos worktrees de prueba." >&2
      ERRORS=$((ERRORS + 1))
    elif [ "$PG_PORT_A" = "$PG_PORT_B" ]; then
      echo "ERROR: dos worktrees del mismo proyecto derivaron el mismo PG_PORT ($PG_PORT_A) -- chocarían en el puerto del host." >&2
      ERRORS=$((ERRORS + 1))
    elif [ "$PROJECT_A" = "$PROJECT_B" ]; then
      echo "ERROR: dos worktrees del mismo proyecto derivaron el mismo COMPOSE_PROJECT_NAME ($PROJECT_A) -- chocarían en contenedores/redes/volúmenes." >&2
      ERRORS=$((ERRORS + 1))
    else
      echo "✔ Worktrees aislados: PG_PORT $PG_PORT_A vs $PG_PORT_B, COMPOSE_PROJECT_NAME $PROJECT_A vs $PROJECT_B."
    fi
  else
    echo "ERROR: worktree-env.sh no generó .env.local en uno de los dos worktrees de prueba." >&2
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "ERROR: 'jq' no está instalado -- no se puede verificar el aislamiento de Postgres entre worktrees. Bloqueo preventivo." >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "✖ Verificación del template falló ($ERRORS problema(s))." >&2
  exit 1
fi

echo "✔ El template genera un proyecto limpio (copier copy + git init + sin Jinja/webstack residual)."
