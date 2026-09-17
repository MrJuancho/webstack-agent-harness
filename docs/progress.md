# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log` y `AGENTS.md` -- no aquí.
-->

## En qué quedó la última sesión

Harness reparado y verificado con `just setup` en verde (fff6ef9): hooks de
`.claude/settings.json` con schema correcto, `gauntlet` migra `webstack_dev`
de verdad (ya no depende del `CREATE TABLE IF NOT EXISTS` manual que tenía
`query-gate.test.ts`), `setup`/`db-reset`/`install-hooks` nuevos. Spec doc
actualizado a v1.1 y spec-kit instalado con constitución sembrada desde
`AGENTS.md` (5129e51). **Hallazgo crítico, corregido y verificado en vivo**:
`guard-holdouts.sh` y `stop-gate.sh` usaban `exit 1`; en Claude Code solo
`exit 2` bloquea `PreToolUse`/`Stop` -- Gate 5 y el Stop gate llevaban desde
su creación sin bloquear nada de verdad. Confirmado con una edición de
prueba real sobre `tests/holdout/` (pasó antes del fix, bloqueada después).
Corregido: ambos scripts a `exit 2`, y `settings.json` ahora invoca via
`${CLAUDE_PROJECT_DIR}` + `|| exit 2` en vez de ruta relativa (la ruta
relativa se resuelve contra el cwd del proceso que dispara el hook, no
necesariamente la raíz del repo).

## Qué sigue

Sin proyecto real encima del harness todavía -- se instanciará clonando
este repo y reiniciando `.git` (no vía GitHub template). Antes de ese clon:
renombrar referencias a `webstack-agent-harness`/`webstack_dev` en
`package.json`, `docker-compose.yml`, badges de `README.md` y el spec doc;
resellar `tests/holdout/` con invariantes reales del proyecto nuevo. Evaluar
adoptar de `gauntlet-template`: ADRs en `docs/adr/`, subagentes
`generator`/`reviewer` con tools restringidas, hook `PostToolUse` de
lint rápido (falla ABIERTO, a diferencia de Gate 5/Stop). Pendiente:
aislar Postgres por worktree antes de usar Orca con agentes en paralelo
(hoy `webstack_dev` y los puertos son compartidos entre worktrees).

## Bloqueado / pendiente de decisión

Ninguno. Decisión ya tomada: clon + `git init` nuevo, no GitHub template.
