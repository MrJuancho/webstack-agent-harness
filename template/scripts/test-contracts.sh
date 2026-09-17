#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/tmp/_gauntlet-contracts.pid"
LOG_FILE="/tmp/server_contracts.log"

cleanup() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$pid" ]; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
}

trap cleanup EXIT INT TERM

# Limpieza preventiva
cleanup

echo "Iniciando servidor para prueba de contratos..."
PORT=3000 pnpm exec tsx src/http/server.ts > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

# Polling activo de disponibilidad (máx 6 segundos)
SERVER_READY=0
for _ in {1..20}; do
  if curl -s http://127.0.0.1:3000/health >/dev/null 2>&1; then
    SERVER_READY=1
    break
  fi
  sleep 0.3
done

if [ "$SERVER_READY" -ne 1 ]; then
  echo "ERROR: El servidor no inició a tiempo. Log de arranque:" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "Servidor respondiendo. Ejecutando Schemathesis..."
docker run --network host --rm \
  schemathesis/schemathesis:stable run http://127.0.0.1:3000/openapi.json \
  -H "Authorization: Bearer test-token" \
  --checks not_a_server_error,status_code_conformance,content_type_conformance,response_schema_conformance \
  --max-examples 25
