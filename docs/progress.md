# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Dos features mergeadas a `main` en la misma sesión (PRs stackeados,
mergeados en orden): (1) aislamiento de Postgres entre worktrees
(`scripts/worktree-env.sh`, `.env.local` con `PG_PORT`/
`COMPOSE_PROJECT_NAME` por worktree, verificado con Docker real); (2)
mutación (Stryker) acotada de verdad a `src/domain/**` (testRunner ahora
apunta a `vitest.config.domain.ts`, sin Postgres; nuevo `just
test-domain`; Gate 9 exige justificación de supresiones). Dos bugs reales
de Stryker+pnpm encontrados y arreglados en el camino -- ver AGENTS.md,
"Dos bugs reales que este trabajo encontró", no reintroducirlos.

Sesiones posteriores (aún stackeadas encima, pendientes de merge):
Gate 10 (ESLint `no-restricted-syntax` prohíbe leer reloj/aleatoriedad en
`src/domain/**`, ver AGENTS.md) y la checklist cerrada del Reviewer (ocho
puntos A-H + veredicto máquina-legible, ver `.claude/agents/reviewer.md`).

Al mergear PR #4 (mutación) después de PR #3 (worktrees), hubo conflicto
real en `scripts/verify-template.sh` y este archivo -- ambos PRs insertan
bloques en el mismo punto del script. Se resolvió a mano conservando
ambos bloques de verificación (worktrees primero, luego mutate-glob/
test-domain). Lección para las siguientes fusiones del stack: esperar
`mergeable` en verde antes de fusionar cada PR, no asumirlo por haber
pasado CI antes de que el anterior mergeara.

## Qué sigue

Mergear en orden los PRs restantes del stack (clock-lint, luego
reviewer-checklist), resolviendo el mismo tipo de conflicto si aparece.

## Bloqueado / pendiente de decisión

Ninguno.
