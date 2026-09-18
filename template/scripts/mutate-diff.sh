#!/usr/bin/env bash
set -euo pipefail

# NOTA: el pathspec es el directorio 'src/domain', no un glob
# 'src/domain/**/*.ts' -- confirmado con una prueba real que git NO trata
# '**' como glob de varios niveles en un pathspec sin magia ':(glob)'
# explícita (ni siquiera con `*.ts` normal), así que ese glob nunca
# matcheaba nada: `just gauntlet-full` corría `mutate:diff` en CADA PR y
# siempre imprimía "Sin cambios detectados", incluso con cambios de
# dominio reales sin commitear -- la mutación sobre diff nunca corrió de
# verdad. El pathspec de directorio evita todo el tema de globs.

# 1. Identificar la base de comparación frente a main
BASE_REF=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo "")

# 2. Obtener archivos modificados commiteados frente a la base
if [ -n "$BASE_REF" ] && [ "$BASE_REF" != "$(git rev-parse HEAD)" ]; then
  TRACKED=$(git diff --name-only --diff-filter=ACMR "$BASE_REF" -- 'src/domain')
else
  TRACKED=$(git diff --name-only --diff-filter=ACMR HEAD -- 'src/domain' 2>/dev/null || true)
fi

# 3. Incluir archivos en working tree (unstaged, staged y sin rastrear)
UNCOMMITTED=$(git diff --name-only --diff-filter=ACMR -- 'src/domain')
STAGED=$(git diff --name-only --cached --diff-filter=ACMR -- 'src/domain')
UNTRACKED=$(git ls-files --others --exclude-standard -- 'src/domain')

# 4. Unificar, quitar tests (mutar el test en vez del código que cubre no
# tiene sentido, y `--mutate` reemplaza por completo el glob `mutate` de
# stryker.config.mjs, así que su exclusión de *.test.ts no aplica acá) y
# limpiar la lista.
ALL_FILES=$(echo -e "${TRACKED}\n${UNCOMMITTED}\n${STAGED}\n${UNTRACKED}" \
  | sed '/^$/d' \
  | { grep -v '\.test\.ts$' || true; } \
  | sort -u \
  | paste -sd, -)

# 5. Salida temprana si no hay código de dominio modificado
if [ -z "$ALL_FILES" ]; then
  echo "Guantelete: Sin cambios detectados en src/domain/. Se omite la mutación."
  exit 0
fi

echo "Guantelete: Mutando archivos en diff: $ALL_FILES"
bash scripts/run-mutation.sh --mutate "$ALL_FILES"
