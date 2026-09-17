#!/usr/bin/env bash
set -euo pipefail

HASH_FILE=".holdout.sha256"

if [ ! -f "$HASH_FILE" ]; then
  echo "ERROR Gate 5: Falta el archivo de firma de hold-outs ($HASH_FILE)." >&2
  exit 1
fi

echo "Gate 5: Verificando integridad de los tests hold-out..."
if ! sha256sum --check --status "$HASH_FILE"; then
  echo "ERROR Gate 5: Los tests hold-out han sido manipulados o modificados. Bloqueo de seguridad." >&2
  sha256sum --check "$HASH_FILE" || true
  exit 1
fi

echo "Gate 5: Integridad verificada. Ejecutando suite hold-out..."
pnpm exec vitest run tests/holdout
