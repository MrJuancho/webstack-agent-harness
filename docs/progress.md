# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Las cuatro features del stack están en `main`: (1) aislamiento de
Postgres entre worktrees (`scripts/worktree-env.sh`, `.env.local`); (2)
mutación (Stryker) acotada a `src/domain/**` (`vitest.config.domain.ts`,
sin Postgres; dos bugs reales de Stryker+pnpm arreglados, ver AGENTS.md,
"Dos bugs reales...", no reintroducirlos); (3) Gate 10 (ESLint
`no-restricted-syntax` prohíbe leer reloj/aleatoriedad en
`src/domain/**`); (4) checklist cerrada del Reviewer (ocho puntos A-H +
veredicto máquina-legible en `.claude/agents/reviewer.md`, que reemplazó
por completo la lista abierta de "reward hacking" anterior).

Mergear un stack de 4 PRs con `--delete-branch` tuvo dos problemas reales,
no hipotéticos: (1) GitHub CIERRA (no retargetea) un PR cuyo branch base
stackeado se borra al mergear el PR anterior -- pasó dos veces, hubo que
reabrir como PRs nuevos (#5→#7) y retargetear #6 a mano ANTES de que su
base se borrara; (2) cada merge subsiguiente generó conflictos reales en
`verify-template.sh`, este archivo, `AGENTS.md.jinja`, `README.md.jinja`
y `reviewer.md` -- varios PRs insertan bloques en el mismo punto de los
mismos archivos. Resuelto a mano, conservando ambos lados en cada caso
(nunca se descartó contenido), verificando `bash scripts/verify-template.sh`
en verde después de cada resolución antes de completar el merge commit.

## Qué sigue

Nada pendiente. Los branches del stack ya fusionados están borrados;
sobrevive `feature/domain-supplements` (rama local vieja, ya contenida en
`main`, no tiene commits propios -- inofensiva, no hace falta borrarla).

## Bloqueado / pendiente de decisión

Ninguno.
