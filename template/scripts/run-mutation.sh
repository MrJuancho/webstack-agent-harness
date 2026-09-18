#!/usr/bin/env bash
# Wrapper de `stryker run` (usado por mutate:diff y mutate:full/audit):
# SIEMPRE imprime cuántos mutantes instrumentados fueron IGNORADOS (vía
# `// Stryker disable`, justificados por Gate 9) después de correr, pase o
# falle la corrida -- un score de 100% puede estar escondiendo que una
# fracción real de los mutantes nunca corrió. Stryker mismo no reporta
# esa cifra en su tabla de resumen; hay que leerla del reporte JSON.
#
# Propaga el código de salida REAL de `stryker run`, nunca el del
# resumen -- que esto exista no debe poder enmascarar un score bajo el
# umbral.
set -uo pipefail

# --full (consumido acá, nunca llega a `stryker run`): usado por `just
# audit`. `mutate:diff` y `audit` comparten stryker.config.mjs, así que
# sin esto compartirían también su .stryker-tmp/incremental.json -- un
# `audit` corrido segundos después de un `mutate:diff` reutilizaría sus
# resultados en vez de recorrer todo, exactamente lo contrario de lo que
# "auditoría nocturna EXHAUSTIVA" promete. Confirmado a mano: sin este
# archivo separado, `audit` reportaba "N of M mutant result(s) are
# reused" cuando corría poco después de un `mutate:diff` en la misma
# sesión.
STRYKER_ARGS=()
for ARG in "$@"; do
  if [ "$ARG" = "--full" ]; then
    STRYKER_ARGS+=(--incrementalFile .stryker-tmp/incremental-audit.json)
  else
    STRYKER_ARGS+=("$ARG")
  fi
done

pnpm exec stryker run "${STRYKER_ARGS[@]}"
CODE=$?

REPORT="reports/mutation/mutation.json"
if [ -f "$REPORT" ]; then
  TOTAL=$(jq '[.files[].mutants[]] | length' "$REPORT" 2>/dev/null || echo 0)
  IGNORED=$(jq '[.files[].mutants[] | select(.status == "Ignored")] | length' "$REPORT" 2>/dev/null || echo 0)
  if [ "${IGNORED:-0}" -gt 0 ]; then
    TESTED=$((TOTAL - IGNORED))
    echo ""
    echo "ℹ ${IGNORED} de ${TOTAL} mutantes instrumentados fueron IGNORADOS (supresiones \`// Stryker disable\`, cada una con justificación exigida por Gate 9) -- el score de arriba es sobre los ${TESTED} restantes, no sobre los ${TOTAL} instrumentados:"
    jq -r '.files | to_entries[] as $f | $f.value.mutants[] | select(.status == "Ignored") | "  " + $f.key + ":" + (.location.start.line | tostring) + " (" + .mutatorName + ") -- " + .statusReason' "$REPORT"
  fi
fi

exit "$CODE"
