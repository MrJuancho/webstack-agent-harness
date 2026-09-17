#!/usr/bin/env bash
# Stop -- corre `just gauntlet-fast` antes de dar un turno por terminado.
#
# NOTA: exit 2 es el UNICO codigo que bloquea un hook Stop en Claude Code;
# exit 1 se trata como no-bloqueante y el turno termina igual (verificado
# contra https://code.claude.com/docs/en/hooks). Tambien resolvemos
# CLAUDE_PROJECT_DIR explicitamente en vez de asumir que el cwd del proceso
# que dispara el hook es la raiz del repo -- un `command` con ruta relativa
# se resuelve contra ESE cwd, no contra la raiz del proyecto.
set -u

if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  echo "CLAUDE_PROJECT_DIR no esta definida -- no se puede verificar nada sin saber donde esta la raiz del proyecto. Bloqueado por seguridad (fail-closed)." >&2
  exit 2
fi

if ! cd "$CLAUDE_PROJECT_DIR"; then
  echo "No se pudo entrar a CLAUDE_PROJECT_DIR ($CLAUDE_PROJECT_DIR) -- bloqueado por seguridad (fail-closed)." >&2
  exit 2
fi

if ! command -v just >/dev/null 2>&1; then
  echo "No se pudo correr el guantelete: falta 'just' en el entorno." >&2
  echo "Instala 'just' o corre 'just doctor' manualmente antes de terminar el turno." >&2
  exit 2
fi

echo "==> Hook Stop: Verificando Nivel 1 del Guantelete antes de autorizar cierre..."
salida=$(just gauntlet-fast 2>&1)
codigo=$?

if [ "$codigo" -eq 0 ]; then
  echo "✔ gauntlet-fast completado con éxito. Turno autorizado."
  exit 0
fi

echo "ERROR: gauntlet-fast falló. El agente no puede cerrar el turno con errores pendientes." >&2
echo "$salida" >&2
exit 2
