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

# Nivel 2: Verificación estructural, arquitectura, deriva, migraciones e integración (<30s)
gauntlet: gauntlet-fast
    pnpm run lint:arch
    just db-up
    just db-drift-check
    just db-migrate-reversible
    pnpm exec vitest run tests/architecture
    pnpm run test:integration

# Nivel 3: Pre-merge y CI (Property testing, Contratos, Seeds, Hold-outs y Mutation del diff)
gauntlet-full: gauntlet
    pnpm run test:property
    just test-contracts
    just db-seed-check
    just test-holdouts
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

# Gate 2: Schema Drift
db-drift-check:
    bash scripts/test-db-drift.sh

# Gate 1: Migraciones Reversibles Up/Down
db-migrate-reversible:
    just db-up
    bash scripts/test-migrations-reversible.sh

# Gate 7: Determinismo de Seeds
db-seed-check:
    just db-up
    bash scripts/test-seed-determinism.sh

# Gate 3: Verificación de Contratos OpenAPI con Schemathesis
test-contracts:
    @command -v docker >/dev/null 2>&1 || (echo "ERROR: Docker es requerido para ejecutar Schemathesis" && exit 1)
    bash scripts/test-contracts.sh

# Gate 5: Verificación e Integridad de Hold-Out Tests
test-holdouts:
    bash scripts/test-holdouts.sh
