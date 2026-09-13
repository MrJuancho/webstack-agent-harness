#!/usr/bin/env bash
set -euo pipefail

BEFORE=$(git status --porcelain src/infra/db/migrations)

pnpm exec drizzle-kit generate

AFTER=$(git status --porcelain src/infra/db/migrations)

if [ "$BEFORE" != "$AFTER" ]; then
  echo "ERROR Gate 2: Schema drift detectado. El esquema TypeScript (schema.ts) no coincide con las migraciones." >&2
  git checkout -- src/infra/db/migrations/ 2>/dev/null || true
  git clean -fd src/infra/db/migrations/ 2>/dev/null || true
  exit 1
fi
