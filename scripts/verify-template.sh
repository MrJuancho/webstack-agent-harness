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
# No requiere Docker: verifica el mecanismo de plantilla, no que la app de
# ejemplo pase su propio gauntlet (eso requeriría Docker + red + varios
# minutos, demasiado caro para correr en cada turno de agente o cada
# commit). SÍ corre un `pnpm install` (sin Docker) para un único check
# barato: que `just test-domain` pasa sin ningún contenedor levantado --
# es justo la propiedad que esa suite existe para garantizar, y no hay
# forma de confirmarla sin ejecutar Vitest de verdad. Deliberadamente más
# barato que un `just gauntlet` real -- ver docs/progress.md para el
# estado de la suite de meta-tests completa que sí lo haría.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SOURCE_DIR=$(mktemp -d)
SCRATCH_DIR=$(mktemp -d)
LINT_JSON_FILE=$(mktemp)
ERRORS=0

cleanup() {
  rm -rf "$SOURCE_DIR" "$SCRATCH_DIR"
  rm -f "$LINT_JSON_FILE"
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

# Checklist del Reviewer: no hay forma mecánica de probar la CALIDAD de una
# revisión, pero sí se puede probar que el prompt con la checklist cerrada
# (las ocho letras + el bloque de veredicto máquina-legible) realmente
# llegó al proyecto generado -- no que se perdió en un refactor de
# copier.yml/_tasks o de la plantilla misma.
REVIEWER_FILE=$(find "$SCRATCH_DIR/.claude/agents" -maxdepth 1 -name 'reviewer.*' 2>/dev/null | head -1)
if [ -z "$REVIEWER_FILE" ]; then
  echo "ERROR: no se encontró .claude/agents/reviewer.* en el proyecto generado." >&2
  ERRORS=$((ERRORS + 1))
else
  REQUIRED_STRINGS=(
    "### A. Tests debilitados"
    "### B. Tests tautológicos"
    "### C. Casos especiales"
    "### D. Marcadores de test desactivado"
    "### E. Errores tragados"
    "### F. Restricciones vueltas opcionales"
    "### G. Supresiones"
    "### H. Fuga de capa"
    "VEREDICTO: APROBADO | CAMBIOS_REQUERIDOS"
    "HALLAZGOS_BLOQUEANTES"
  )
  MISSING_CHECKLIST=()
  for REQUIRED in "${REQUIRED_STRINGS[@]}"; do
    grep -qF "$REQUIRED" "$REVIEWER_FILE" || MISSING_CHECKLIST+=("$REQUIRED")
  done
  if [ "${#MISSING_CHECKLIST[@]}" -gt 0 ]; then
    echo "ERROR: a $REVIEWER_FILE le falta(n) parte(s) de la checklist obligatoria del Reviewer:" >&2
    printf '  - %s\n' "${MISSING_CHECKLIST[@]}" >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "✔ $REVIEWER_FILE tiene las ocho letras de la checklist y el bloque de veredicto."
  fi
fi

# Alcance de la mutación (Stryker): el glob `mutate` del proyecto generado
# no debe cubrir nada fuera de src/domain. Si se filtra un glob más
# amplio, Stryker vuelve a mutar handlers/adaptadores -- el costo alto y
# la señal baja que esta convención existe para evitar -- sin que nada lo
# marque.
MUTATE_BLOCK=$(sed -n '/mutate:\s*\[/,/\]/p' "$SCRATCH_DIR/stryker.config.mjs" 2>/dev/null || true)
if [ -z "$MUTATE_BLOCK" ]; then
  echo "ERROR: no se encontró el bloque 'mutate:' en stryker.config.mjs del proyecto generado." >&2
  ERRORS=$((ERRORS + 1))
else
  BAD_GLOBS=$(printf '%s\n' "$MUTATE_BLOCK" | grep -oP "'[^']*'" | tr -d "'" | grep -vE '^!?src/domain/' || true)
  if [ -n "$BAD_GLOBS" ]; then
    echo "ERROR: stryker.config.mjs 'mutate' incluye rutas fuera de src/domain:" >&2
    echo "$BAD_GLOBS" >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "✔ stryker.config.mjs: 'mutate' está acotado a src/domain."
  fi
fi

# `just test-domain` debe pasar sin ningún contenedor Docker levantado --
# nunca corremos `just db-up` ni `docker compose` en este script, así que
# un test-domain en verde acá prueba justo eso: la suite de dominio no
# depende de Postgres para nada.
if command -v just >/dev/null 2>&1 && command -v pnpm >/dev/null 2>&1; then
  echo "==> Verificando 'just test-domain' sin Postgres levantado (proyecto generado)..."
  TEST_DOMAIN_LOG=$(cd "$SCRATCH_DIR" && pnpm install --frozen-lockfile 2>&1 && just test-domain 2>&1)
  TEST_DOMAIN_CODE=$?
  if [ "$TEST_DOMAIN_CODE" -ne 0 ]; then
    echo "ERROR: 'just test-domain' falló en el proyecto generado (sin Docker levantado):" >&2
    echo "$TEST_DOMAIN_LOG" >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "✔ 'just test-domain' pasa sin ningún contenedor Docker levantado."
  fi
else
  echo "ERROR: 'just' y/o 'pnpm' no están instalados -- no se puede verificar 'just test-domain'. Bloqueo preventivo." >&2
  ERRORS=$((ERRORS + 1))
fi

# Gate 10 (determinismo del dominio, ESLint no-restricted-syntax): el modo
# de falla real de un gate de análisis estático no es que la regla esté
# mal escrita, es que no aplique -- un glob que no matchea, o un bloque de
# la config plana en el orden equivocado, y queda de adorno pasando en
# verde para siempre. Copia el fixture (tests/fixtures/clock-violations.ts.txt
# -- un caso de cada patrón prohibido, más los casos que sí deben pasar)
# como src/domain/__clock_check__.ts DENTRO del proyecto generado, corre
# ESLint de verdad, y afirma tanto que falla como el conteo EXACTO de
# violaciones -- "falló con algo" no basta, un gate que no se prueba a sí
# mismo no es un gate.
EXPECTED_CLOCK_VIOLATIONS=7
if command -v jq >/dev/null 2>&1 && [ -d "$SCRATCH_DIR/node_modules" ]; then
  echo "==> Verificando Gate 10 (determinismo del dominio) con el fixture real..."
  CLOCK_FIXTURE_TARGET="$SCRATCH_DIR/src/domain/__clock_check__.ts"
  cp "$SCRATCH_DIR/tests/fixtures/clock-violations.ts.txt" "$CLOCK_FIXTURE_TARGET"

  ( cd "$SCRATCH_DIR" && pnpm exec eslint --format json src/domain/__clock_check__.ts >"$LINT_JSON_FILE" 2>/dev/null )

  rm -f "$CLOCK_FIXTURE_TARGET"

  ACTUAL_VIOLATIONS=$(jq '[.[0].messages[]? | select(.ruleId == "no-restricted-syntax")] | length' "$LINT_JSON_FILE" 2>/dev/null || echo "")
  TOTAL_MESSAGES=$(jq '.[0].messages | length' "$LINT_JSON_FILE" 2>/dev/null || echo "")

  if [ -z "$ACTUAL_VIOLATIONS" ] || [ -z "$TOTAL_MESSAGES" ]; then
    echo "ERROR: Gate 10 no produjo un reporte JSON de ESLint válido -- ¿'pnpm exec eslint' rompió?" >&2
    cat "$LINT_JSON_FILE" >&2
    ERRORS=$((ERRORS + 1))
  elif [ "$ACTUAL_VIOLATIONS" != "$EXPECTED_CLOCK_VIOLATIONS" ] || [ "$TOTAL_MESSAGES" != "$EXPECTED_CLOCK_VIOLATIONS" ]; then
    echo "ERROR: Gate 10 esperaba exactamente $EXPECTED_CLOCK_VIOLATIONS violaciones de 'no-restricted-syntax' (y ningún otro mensaje) en el fixture; encontró $ACTUAL_VIOLATIONS de no-restricted-syntax entre $TOTAL_MESSAGES mensajes totales. El gate no está aplicando como se espera -- revisar el glob 'files' de src/domain/**/*.ts en eslint.config.js y el orden de los bloques de la config plana." >&2
    cat "$LINT_JSON_FILE" >&2
    ERRORS=$((ERRORS + 1))
  else
    echo "✔ Gate 10: el fixture produce exactamente $EXPECTED_CLOCK_VIOLATIONS violaciones de no-restricted-syntax, como se esperaba."
  fi
else
  echo "ERROR: 'jq' no está instalado, o no hay node_modules en el proyecto generado -- no se puede verificar Gate 10. Bloqueo preventivo." >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "✖ Verificación del template falló ($ERRORS problema(s))." >&2
  exit 1
fi

echo "✔ El template genera un proyecto limpio (copier copy + git init + sin Jinja/webstack residual)."
