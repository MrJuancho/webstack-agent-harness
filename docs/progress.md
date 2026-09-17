# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Migración completa a Copier (ADR-0003, supera ADR-0002 del día anterior):
todo el proyecto bajo `template/`, `copier.yml` en la raíz, variables
`project_name`/`package_name`/`db_name`/`github_owner`. La raíz ya no es un
proyecto corriendo -- es la gestión del template (`copier.yml`, `docs/adr/`,
este archivo). Verificado con una corrida REAL de `copier copy` (fuente sin
`.git`, para evitar el bug de `dunamai` con el tag `v1.0.0-harness`) seguida
de `just setup` y `just gauntlet` completos en el proyecto generado -- las
dos veces encontró y forzó a corregir bugs reales que la sola lectura de
código no hubiera atrapado: `copier copy` no corre `git init` solo (rompía
`just install-hooks`), y dos scripts de gates tenían nombres de bases de
datos efímeras hardcodeados con "webstack". Ambos corregidos y
reverificados en verde. `justfile` deliberadamente sin sufijo `.jinja`
(colisiona con la sintaxis `{{}}` de `just`) -- ver ADR-0003 para el
detalle completo de los 5 hallazgos de la migración.

## Qué sigue

El tag viejo `v1.0.0-harness` (no PEP 440 válido, rompía `dunamai`) se
resolvió taggeando este mismo commit de migración como `v0.1.0` -- Copier
encuentra el tag más cercano a HEAD primero, así que `copier copy
<url-de-github>` ya no debería necesitar `--vcs-ref HEAD` explícito. El tag
viejo se deja intacto como historia, no se borra.

Sigue sin existir una suite de meta-tests que verifique el mecanismo del
template en sí (lo que sí tiene `gauntlet-template`) -- la verificación de
hoy fue manual, una vez. Consecuencia directa, encontrada al intentar
commitear este mismo cambio: el pre-commit hook local ya no puede correr
`just gauntlet-fast` (no hay `template/package.json` real, solo
`.jinja` -- no renderiza sin un `copier copy`), así que quedó como no-op
honesto. Tampoco existe ya `.claude/settings.json` en la raíz (se movió a
`template/.claude/`) -- Capa 1 (hooks de agente) no está activa editando
este repo raíz hasta que se construya un `.claude/` propio para la raíz,
apuntando a `template/scripts/hooks/*` y a `template/tests/holdout/`. Sin
proyecto real generado todavía.

## Bloqueado / pendiente de decisión

Ninguno.
