#!/usr/bin/env bash
set -euo pipefail

# 1. Identificar la base de comparación frente a main
BASE_REF=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "")

# 2. Obtener archivos modificados commiteados frente a la base
if [ -n "$BASE_REF" ] && [ "$BASE_REF" != "$(git rev-parse HEAD)" ]; then
  TRACKED=$(git diff --name-only --diff-filter=ACMR "$BASE_REF" -- 'src/domain/**/*.ts')
else
  TRACKED=$(git diff --name-only --diff-filter=ACMR HEAD -- 'src/domain/**/*.ts' 2>/dev/null || true)
fi

# 3. Incluir archivos en working tree (unstaged, staged y sin rastrear)
UNCOMMITTED=$(git diff --name-only --diff-filter=ACMR -- 'src/domain/**/*.ts')
STAGED=$(git diff --name-only --cached --diff-filter=ACMR -- 'src/domain/**/*.ts')
UNTRACKED=$(git ls-files --others --exclude-standard -- 'src/domain/**/*.ts')

# 4. Unificar y limpiar lista
ALL_FILES=$(echo -e "${TRACKED}\n${UNCOMMITTED}\n${STAGED}\n${UNTRACKED}" | sed '/^$/d' | sort -u | paste -sd, -)

# 5. Salida temprana si no hay código de dominio modificado
if [ -z "$ALL_FILES" ]; then
  echo "Guantelete: Sin cambios detectados en src/domain/. Se omite la mutación."
  exit 0
fi

echo "Guantelete: Mutando archivos en diff: $ALL_FILES"
pnpm exec stryker run --mutate "$ALL_FILES"
