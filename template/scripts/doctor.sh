#!/usr/bin/env bash
set -euo pipefail

echo "==> Verificando dependencias del arnés (Fail-Closed Doctor)..."

ERRORS=0

check_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  ✔ $name: $(command -v "$cmd")"
  else
    echo "  ✖ $name: NO ENCONTRADO ($cmd)" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. Herramientas base
check_cmd "Node.js (>=22)" "node"
check_cmd "pnpm" "pnpm"
check_cmd "Docker" "docker"
check_cmd "Docker Compose" "docker"
check_cmd "Gitleaks (Gate 8)" "gitleaks"
check_cmd "jq (Procesador JSON)" "jq"
check_cmd "curl" "curl"
check_cmd "sha256sum" "sha256sum"

# 2. Utilidades de base de datos dentro del host/WSL
if command -v docker >/dev/null 2>&1; then
  if docker compose exec -T postgres pg_isready >/dev/null 2>&1; then
    echo "  ✔ PostgreSQL 16 (tmpfs): Conectado y listo"
  else
    echo "  ⚠ PostgreSQL 16 (tmpfs): Contenedor inactivo o no responde (ejecutar 'just db-up')"
  fi
fi

# 3. Validar versión de Node.js
NODE_MAJOR=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "  ✖ Node.js versión incompatible: Se requiere >= 22 (Detectada: $(node -v))" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "" >&2
  echo "ERROR: Fallaron $ERRORS verificaciones del sistema. El arnés se niega a operar." >&2
  exit 1
fi

echo "✔ Todas las dependencias están operativas."
