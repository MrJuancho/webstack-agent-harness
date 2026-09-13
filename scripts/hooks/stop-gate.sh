#!/usr/bin/env bash
set -euo pipefail

echo "==> Hook Stop: Verificando Nivel 1 del Guantelete antes de autorizar cierre..."
if ! just gauntlet-fast; then
  echo "ERROR: gauntlet-fast falló. El agente no puede cerrar el turno con errores pendientes." >&2
  exit 1
fi

echo "✔ gauntlet-fast completado con éxito. Turno autorizado."
