#!/usr/bin/env bash
# PostToolUse -- feedback rapido de ESLint tras cada Edit/Write sobre un
# .ts, SIN bloquear nada.
#
# Este es un componente de CONVENIENCIA, no de seguridad: falla ABIERTO.
# Si falta una herramienta (jq, pnpm) o no se puede determinar la ruta del
# archivo, simplemente no da feedback -- no debe impedir que la edicion
# ya aplicada quede en pie. Contrasta a proposito con guard-holdouts.sh y
# stop-gate.sh, que fallan CERRADO porque protegen invariantes de
# seguridad, no solo dan feedback de estilo. Ver AGENTS.md, seccion
# "Que falla cerrado y que falla abierto", para el criterio completo.
#
# exit 2 aqui no bloquea nada (la herramienta ya corrio) -- solo hace que
# el hallazgo de ESLint se muestre a Claude como contexto inmediato en vez
# de quedar solo en el log de depuracion (ver https://code.claude.com/docs/en/hooks).
set -u

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
[ -n "$FILE_PATH" ] || exit 0

case "$FILE_PATH" in
  *.ts) ;;
  *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0
[ -n "${CLAUDE_PROJECT_DIR:-}" ] || exit 0
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
command -v pnpm >/dev/null 2>&1 || exit 0

LINT_OUTPUT=$(pnpm exec eslint "$FILE_PATH" 2>&1)
LINT_CODE=$?

[ "$LINT_CODE" -eq 0 ] && exit 0

echo "ESLint encontró problemas en $FILE_PATH (feedback rápido, no bloqueante -- corrígelo antes de terminar el turno, gauntlet-fast lo exigirá igual):" >&2
echo "$LINT_OUTPUT" >&2
exit 2
