# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Tres features mergeadas a `main` (PRs stackeados, en orden): (1)
aislamiento de Postgres entre worktrees (`scripts/worktree-env.sh`,
`.env.local` con `PG_PORT`/`COMPOSE_PROJECT_NAME`); (2) mutación
(Stryker) acotada de verdad a `src/domain/**` (`vitest.config.domain.ts`,
sin Postgres; `just test-domain`; Gate 9 exige justificación de
supresiones -- dos bugs reales de Stryker+pnpm arreglados en el camino,
ver AGENTS.md, "Dos bugs reales...", no reintroducirlos); (3) Gate 10
(ESLint `no-restricted-syntax` prohíbe leer reloj/aleatoriedad en
`src/domain/**`).

Pendiente, aún stackeada: checklist cerrada del Reviewer (ocho puntos A-H
+ veredicto máquina-legible, `.claude/agents/reviewer.md`, PR #6). Su
base se tuvo que retargetear a `main` a mano: GitHub CIERRA (no
retargetea) un PR cuyo branch base stackeado se borra al mergear el PR
anterior -- pasó con el PR de Gate 10 también (se reabrió como PR nuevo).

Cada merge tuvo conflicto real en `verify-template.sh`, este archivo,
`AGENTS.md.jinja`, `README.md.jinja` y `reviewer.md` -- varios PRs
insertan bloques en el mismo punto de los mismos archivos. Resuelto a
mano conservando ambos lados siempre. Lección: esperar `mergeable:
MERGEABLE` + CI verde antes de cada merge del stack, y retargetear los
PRs dependientes a `main` ANTES de borrar la rama de la que dependen.

## Qué sigue

Mergear PR #6 (reviewer-checklist) a `main`, resolviendo el mismo tipo de
conflicto si aparece.

## Bloqueado / pendiente de decisión

Ninguno.
