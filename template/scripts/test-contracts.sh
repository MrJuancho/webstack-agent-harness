#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/tmp/_gauntlet-contracts.pid"
LOG_FILE="/tmp/server_contracts.log"

cleanup() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$pid" ]; then
      # SIGTERM primero (apagado ordenado de src/http/server.ts); SIGKILL
      # solo si en 5s no terminó.
      kill "$pid" 2>/dev/null || true
      for _ in {1..50}; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
}

trap cleanup EXIT INT TERM

# Limpieza preventiva
cleanup

echo "Iniciando servidor para prueba de contratos..."
# `node` directo, no `pnpm exec tsx`: así $! ES el servidor. Con el
# envoltorio de pnpm, $! era el envoltorio -- matarlo dejaba el proceso
# node real vivo y dueño del puerto 3000, y cada corrida siguiente
# auditaba en silencio ESE servidor viejo (código viejo) mientras el
# nuevo moría con EADDRINUSE.
PORT=3000 node --import tsx src/main.ts > "$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"

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

# Que algo responda en el 3000 no prueba que sea ESTE servidor: si el
# puerto ya estaba ocupado, el nuestro murió al arrancar y /health lo
# contestó otro proceso.
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "ERROR Gate 3: el servidor de esta corrida no está vivo -- el puerto 3000 lo tiene otro proceso, y Schemathesis auditaría ese. Log de arranque:" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

# Token real: requireAuth verifica firma y vencimiento, así que un
# "Bearer cualquier-cosa" ya no pasa -- Schemathesis solo vería 401 y el
# contrato de las rutas protegidas quedaría sin auditar.
CONTRACT_TOKEN=$(pnpm exec tsx src/infra/auth/dev-token.ts contract-tests)

# El 401 está documentado en el contrato: si el servidor rechazara este
# token, Schemathesis vería solo 401 en cada ruta protegida y reportaría
# todo en verde sin haber auditado ninguna respuesta real. Se confirma
# que el token entra antes de confiar en la corrida.
TOKEN_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${CONTRACT_TOKEN}" http://127.0.0.1:3000/api/v1/profile)
if [ "$TOKEN_STATUS" != "200" ]; then
  echo "ERROR Gate 3: el servidor respondió ${TOKEN_STATUS} (no 200) al token de contratos -- Schemathesis no estaría auditando las rutas protegidas." >&2
  exit 1
fi

echo "Servidor respondiendo. Ejecutando Schemathesis..."
docker run --network host --rm \
  schemathesis/schemathesis:stable run http://127.0.0.1:3000/openapi.json \
  -H "Authorization: Bearer ${CONTRACT_TOKEN}" \
  --checks not_a_server_error,status_code_conformance,content_type_conformance,response_schema_conformance \
  --max-examples 25
