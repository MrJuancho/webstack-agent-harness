# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, `AGENTS.md` y `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Harness reparado, documentado y con verificación de agentes reforzada
(commits fff6ef9, 5129e51, c42d4d5, + este). Hallazgo crítico corregido y
sellado en `docs/adr/0001`: `guard-holdouts.sh`/`stop-gate.sh` usaban
`exit 1`; solo `exit 2` bloquea `PreToolUse`/`Stop` en Claude Code -- ambos
llevaban sin bloquear nada desde su creación. Verificado en vivo dos veces
(antes y después del fix) con una edición real sobre el hold-out sellado.
Agregado desde ahí, mirando a `gauntlet-template` como referencia madura:
subagentes `generator`/`reviewer` en `.claude/agents/` (con tools
restringidas de verdad, no solo convención en prosa); regla explícita de
aislamiento de worktrees para roles de verificación en `AGENTS.md`; hook
`PostToolUse` (`lint-on-edit.sh`) de feedback rápido de ESLint, falla
ABIERTO a propósito, documentado junto a la tabla fail-closed/fail-open;
`docs/adr/` con dos decisiones (exit-2, y clon+`git init` en vez de GitHub
template); constitución a v1.1.0 (principio VI: presupuesto por tokens, no
reloj). Spec doc a v1.2, README y `AGENTS.md` actualizados en el mismo
cambio. `just gauntlet-fast` verde en cada paso.

## Qué sigue

Sin proyecto real encima del harness todavía. Antes de clonar: renombrar
`webstack-agent-harness`/`webstack_dev` en `package.json`,
`docker-compose.yml`, badges de `README.md` y el spec doc; resellar
`tests/holdout/` con invariantes reales. Pendiente, explícitamente fuera de
alcance por decisión del usuario: **no** atar el aislamiento de worktrees a
Orca ni a ningún ADE específico -- debe seguir funcionando con `git
worktree` puro. Aislar Postgres por worktree sigue sin resolver si algún
día se corren roles de verificación en paralelo de verdad.

## Bloqueado / pendiente de decisión

Ninguno.
