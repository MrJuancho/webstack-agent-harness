#!/usr/bin/env bash
set -euo pipefail

# Leer input JSON de stdin (estándar de hooks de agentes)
INPUT=$(cat)

# Si jq falla o no puede procesar el JSON, FALLA CERRADO de inmediato
# NOTA: exit 2 es el UNICO codigo que bloquea un hook PreToolUse en Claude
# Code; exit 1 se trata como no-bloqueante y la herramienta procede igual
# (verificado contra https://code.claude.com/docs/en/hooks).
if ! echo "$INPUT" | jq empty >/dev/null 2>&1; then
  echo "ERROR FATAL: Hook no pudo procesar el payload de entrada. Bloqueo preventivo." >&2
  exit 2
fi

# Extraer rutas de archivos involucradas en la llamada a la herramienta
TARGET_PATH=$(echo "$INPUT" | jq -r '
  .tool_input.path // 
  .tool_input.file_path // 
  .tool_input.command // 
  ""' 2>/dev/null || echo "")

if [ -z "$TARGET_PATH" ]; then
  # Si la herramienta no especifica ruta (o no es de filesystem), permitir avance
  exit 0
fi

# Bloquear intentos de escritura o manipulación sobre holdouts o su sello
if echo "$TARGET_PATH" | grep -qE '(tests/holdout|\.holdout\.sha256)'; then
  echo "ACCESO DENEGADO (Gate 5): 'tests/holdout/' y '.holdout.sha256' son inmutables para el agente." >&2
  echo "Cualquier alteración de invariantes de seguridad requiere intervención humana directa." >&2
  exit 2
fi

exit 0
