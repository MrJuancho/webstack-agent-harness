set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Inicialización determinista del entorno para nuevos clones o agentes
setup:
    just doctor
    pnpm install --frozen-lockfile
    just install-hooks
    just db-reset
    just gauntlet
    @echo "✔ Entorno completamente inicializado y verificado en verde."

# Instala el git pre-commit hook (Capa 2) en este clon local
install-hooks:
    cp scripts/hooks/pre-commit.sh .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    @echo "✔ Pre-commit hook instalado (Capa 2 activa)."

# Diagnóstico fail-closed de herramientas
doctor:
    bash scripts/doctor.sh

# Nivel 1: Hook de agente / pre-commit (<5s)
gauntlet-fast:
    @command -v pnpm >/dev/null 2>&1 || (echo "ERROR: pnpm ausente" && exit 1)
    @command -v gitleaks >/dev/null 2>&1 || (echo "ERROR: gitleaks ausente" && exit 1)
    gitleaks protect --staged --verbose
    pnpm run typecheck
    pnpm run lint
    pnpm run test:unit

# Nivel 2: Verificación estructural, arquitectura, deriva, migraciones e integración
gauntlet: gauntlet-fast
    pnpm run lint:arch
    just db-up
    pnpm run db:migrate
    just db-drift-check
    just db-migrate-reversible
    pnpm exec vitest run tests/architecture
    pnpm run test:integration

# Nivel 3: Pre-merge y CI (Property testing, Contratos, Seeds, Hold-outs y Mutation)
gauntlet-full: gauntlet
    pnpm run test:property
    just test-contracts
    just db-seed-check
    just test-holdouts
    pnpm run mutate:diff

# Nivel 4: Auditoría nocturna exhaustiva
audit:
    pnpm run mutate:full

# Infraestructura y Base de Datos (Proyecto unificado)
db-up:
    docker compose -p webstack-agent-harness up -d
    @docker compose -p webstack-agent-harness exec -T postgres pg_isready -U postgres -d webstack_dev || (echo "Esperando a postgres..." && sleep 2)

db-down:
    docker compose -p webstack-agent-harness down

db-reset:
    just db-up
    @docker compose -p webstack-agent-harness exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS webstack_dev;" >/dev/null
    @docker compose -p webstack-agent-harness exec -T postgres psql -U postgres -c "CREATE DATABASE webstack_dev;" >/dev/null
    pnpm run db:migrate

db-generate:
    pnpm exec drizzle-kit generate

db-drift-check:
    bash scripts/test-db-drift.sh

db-migrate-reversible:
    just db-up
    bash scripts/test-migrations-reversible.sh

db-seed-check:
    just db-up
    bash scripts/test-seed-determinism.sh

test-contracts:
    @command -v docker >/dev/null 2>&1 || (echo "ERROR: Docker ausente" && exit 1)
    bash scripts/test-contracts.sh

test-holdouts:
    bash scripts/test-holdouts.sh

# RUTA EXCLUSIVA HUMANA: Sellado de suite hold-out
seal-holdouts:
    @echo "==> ATENCIÓN: Sellando tests hold-out con firma SHA-256..."
    find tests/holdout -type f -name "*.ts" | sort | xargs sha256sum > .holdout.sha256
    @echo "✔ Sello actualizado en .holdout.sha256"

# Orquestación de Worktrees de Revisión
review-start BRANCH="HEAD":
    @git worktree remove ../reviewer-workspace --force 2>/dev/null || true
    @rm -rf ../reviewer-workspace
    @git worktree prune
    git worktree add --detach ../reviewer-workspace {{BRANCH}}
    cd ../reviewer-workspace && pnpm install --frozen-lockfile
    @echo "✔ Worktree de revisión listo en ../reviewer-workspace"

review-clean:
    git worktree remove ../reviewer-workspace --force 2>/dev/null || true
    @rm -rf ../reviewer-workspace
    git worktree prune
    @echo "✔ Worktree de revisión desmontado y podado"
