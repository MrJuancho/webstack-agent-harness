set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Nivel 1: Hook de agente / pre-commit (<5s)
gauntlet-fast:
    @command -v pnpm >/dev/null 2>&1 || (echo "ERROR: pnpm no está instalado o no está en PATH" && exit 1)
    @command -v gitleaks >/dev/null 2>&1 || (echo "ERROR: gitleaks no está instalado. Bloqueo de seguridad preventivo." && exit 1)
    gitleaks protect --staged --verbose
    pnpm run typecheck
    pnpm run lint
    pnpm run test:unit

# Nivel 2: Verificación estructural y arquitectura (<30s)
gauntlet: gauntlet-fast
    pnpm run lint:arch

# Nivel 3: Pre-merge y CI (Property testing y Mutation del diff)
gauntlet-full: gauntlet
    pnpm run test:property
    pnpm run mutate:diff

# Nivel 4: Auditoría nocturna (Mutation testing completo)
audit:
    pnpm run mutate:full
