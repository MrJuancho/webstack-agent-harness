# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Mutación (Stryker) acotada de verdad a `src/domain/**`: el glob `mutate`
ya lo estaba, pero el testRunner apuntaba a `vitest.config.ts` completo
(con Postgres). Ahora apunta a `vitest.config.domain.ts` (nuevo, sin
Postgres, sin globalSetup). Nuevo `just test-domain` (<1s), Gate 9
(`check-stryker-suppressions`: supresión de Stryker sin justificar falla
`gauntlet`), tests de dominio co-ubicados en `src/domain/*.test.ts`.

**Dos bugs reales encontrados corriendo Stryker de verdad (documentados
en AGENTS.md, no reintroducir):** faltaba `.npmrc` (`node-linker=hoisted`)
-- sin él pnpm no encuentra `@stryker-mutator/vitest-runner`,
`mutate:full`/`mutate:diff` fallaban siempre en cualquier proyecto
generado. Y `scripts/mutate-diff.sh` usaba pathspecs
`'src/domain/**/*.ts'` que git nunca matcheaba -- `mutate:diff` (en
`gauntlet-full`, corre antes de cada PR) siempre decía "Sin cambios
detectados" con cambios de dominio reales sin commitear. Ambos arreglados
y verificados con corridas reales: antes `mutate:full` no corría nada;
después `just audit` ~5s en verde, score 76.47%→100% con 2 tests nuevos y
2 supresiones justificadas (mutantes genuinamente equivalentes).

## Qué sigue

PR de este cambio en curso, en paralelo con otro PR (aislamiento de
Postgres entre worktrees, rama `feat/worktree-postgres-isolation`) --
ambos independientes entre sí, ninguno depende del otro para funcionar.

## Bloqueado / pendiente de decisión

Ninguno.
