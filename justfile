set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Nivel 1: Hook de agente / pre-commit (<5s)
gauntlet-fast:
    @command -v pnpm >/dev/null 2>&1 || (echo "ERROR: pnpm no está instalado o no está en PATH" && exit 1)
    @command -v gitleaks >/dev/null 2>&1 || (echo "ERROR: gitleaks no está instalado. Bloqueo preventivo." && exit 1)
    gitleaks protect --staged --verbose
    pnpm run typecheck
    pnpm run lint
    pnpm run test:unit

# Nivel 2: Verificación estructural, arquitectura y deriva de esquema (<30s)
gauntlet: gauntlet-fast
    pnpm run lint:arch
    just db-drift-check

# Nivel 3: Pre-merge y CI (Property testing y Mutation del diff)
gauntlet-full: gauntlet
    pnpm run test:property
    pnpm run mutate:diff

# Nivel 4: Auditoría nocturna (Mutation testing completo)
audit:
    pnpm run mutate:full

# Infraestructura y Base de Datos
db-up:
    docker compose up -d
    @docker compose exec -T postgres pg_isready -U postgres -d webstack_dev || (echo "Esperando a postgres..." && sleep 2)

db-down:
    docker compose down

db-generate:
    pnpm exec drizzle-kit generate

db-drift-check:
    pnpm exec drizzle-kit generate
    @if git status --porcelain src/infra/db/migrations | grep -qE '^(\?\?|.[MARDU])'; then \
        echo "ERROR: Schema drift detectado. Hay cambios en TypeScript sin migración generada o staged." >&2; \
        exit 1; \
    fi
