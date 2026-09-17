# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Cerrada la brecha de Capa 1 que dejó la migración a Copier (commit
8e3ca9f, v0.1.0). Nuevo `scripts/verify-template.sh`: corre un `copier
copy` real sobre el working tree actual y falla si el resultado tiene
regresiones ya conocidas (copy roto, sin `.git`, Jinja sin renderizar,
"webstack" residual). Verificado en ambas direcciones: detecta una
regresión inducida a propósito, y pasa en verde en estado limpio.

Hallazgo importante durante la construcción: apuntar `copier copy`
directamente a este repo (con `.git`) NO refleja cambios sin commitear de
forma confiable -- una tarea `_tasks` marcador nunca corrió estando sin
commitear, y sí corrió recién al commitear. `verify-template.sh` evita
esto copiando primero a un directorio sin `.git` (mismo patrón que se usó
toda la sesión para pruebas manuales).

Root `.claude/settings.json` reinstalado: `PreToolUse` reapunta a
`template/scripts/hooks/guard-holdouts.sh` (mismo script, protege por
substring, cubre la nueva ubicación sin cambios), `Stop` corre
`scripts/verify-template.sh`. **Sin verificar en vivo todavía** -- un
intento real de editar `template/tests/holdout/...` vía Bash NO fue
bloqueado (el script en sí sí bloquea, probado en aislamiento; el
settings.json es nuevo en esta sesión, y a diferencia de un *edit* a un
settings.json ya existente, Claude Code no parece recargar en caliente un
archivo que no existía al iniciar la sesión). Pre-commit local
reinstalado y sí probado (corre en cada commit real de esta sesión).

## Qué sigue

**Confirmar en una sesión nueva** que el hook `PreToolUse`/`Stop` de la
raíz sí bloquea en vivo (reintentar el mismo experimento: editar
`template/tests/holdout/...`). Si sigue sin bloquear, el problema no es
de recarga en caliente sino algo más -- investigar entonces.

## Bloqueado / pendiente de decisión

Ninguno.
