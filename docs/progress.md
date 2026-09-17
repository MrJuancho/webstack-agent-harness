# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

**Confirmado en vivo, en una sesión nueva:** el `PreToolUse` de la raíz
(commit ee711c1) bloqueó un intento real de editar
`template/tests/holdout/...`. Capa 1 de la raíz operativa de punta a
punta -- el problema de la sesión anterior era exactamente recarga en
caliente de un `settings.json` nuevo, como se sospechaba, y se resolvió
solo con la sesión nueva.

Segunda pasada de auditoría (misma sesión que confirmó lo anterior):
verificado con `gh api` que **branch protection en `main` no está
activo** (404 "Branch not protected") -- Capa 4, documentada en
`template/AGENTS.md.jinja` como algo que "debe confirmarse periódicamente
activo", nunca se había confirmado para este repo raíz. Y **no existe
`.github/workflows/` en la raíz** -- `scripts/verify-template.sh` solo
corre vía el hook git local (opcional, no instalado por defecto en un
clon nuevo) o el Stop hook de Claude Code (depende de la sesión); nada lo
corre en CI. Un push directo o un commit con `--no-verify` puede romper
el mecanismo del template sin que nada lo atrape.

## Qué sigue

Dos hallazgos sin resolver, del mismo tipo que motivó Layer 1 hoy --
verificación que existe en la documentación pero no en la práctica:

1. Agregar `.github/workflows/verify-template.yml` en la raíz: instala
   `copier` y corre `scripts/verify-template.sh` en cada push/PR a `main`.
2. Activar branch protection en `main` (requiere GitHub Settings, no se
   puede hacer solo con código) -- posiblemente exigiendo el check de (1)
   una vez exista.

## Bloqueado / pendiente de decisión

Ninguno.
