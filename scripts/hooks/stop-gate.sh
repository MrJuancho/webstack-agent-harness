#!/usr/bin/env bash
# Stop -- corre scripts/verify-template.sh antes de dar un turno por
# terminado en este repo (el template en sí, no un proyecto generado).
#
# exit 2 es el único código que bloquea un hook Stop en Claude Code (ver
# docs/adr/0001-hooks-de-seguridad-usan-exit-2.md, encontrado y corregido
# en template/scripts/hooks/ -- el mismo criterio aplica aquí).
set -u

if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo "CLAUDE_PROJECT_DIR no está definida -- bloqueado por seguridad (fail-closed)." >&2
  exit 2
fi

if ! cd "$CLAUDE_PROJECT_DIR"; then
  echo "No se pudo entrar a CLAUDE_PROJECT_DIR ($CLAUDE_PROJECT_DIR) -- bloqueado por seguridad (fail-closed)." >&2
  exit 2
fi

if [ ! -f scripts/verify-template.sh ]; then
  echo "No se encontró scripts/verify-template.sh -- bloqueado por seguridad (fail-closed)." >&2
  exit 2
fi

salida=$(bash scripts/verify-template.sh 2>&1)
codigo=$?

if [ "$codigo" -eq 0 ]; then
  echo "✔ verify-template.sh en verde. Turno autorizado."
  exit 0
fi

echo "verify-template.sh falló -- arregla esto antes de terminar el turno:" >&2
echo "$salida" >&2
exit 2
