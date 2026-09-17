# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Cerrados los dos hallazgos de la auditoría de Capa 3/4: `.github/workflows/verify-template.yml`
corre `scripts/verify-template.sh` en cada push/PR (job real, verificado en verde:
https://github.com/MrJuancho/webstack-agent-harness/actions/runs/35197153660).
Branch protection activada en `main` con `gh api` -- requiere PR + ese check,
`enforce_admins: true`. Verificado en vivo dos veces: con
`enforce_admins: false` un push directo del dueño pasó igual ("Bypassed rule
violations" -- hallazgo real, no hipotético); con `enforce_admins: true`,
el mismo tipo de push fue rechazado de verdad (GH006). El flujo PR
completo (branch → push → PR #1 → check verde → squash merge → delete
branch) se probó de punta a punta, no solo se configuró.

Decisión explícita del usuario: en vez de "requerir CI pero permitir push
directo" (que GitHub no soporta para un commit nuevo -- el check no puede
existir antes del primer push), se adoptó PR obligatorio para este repo
raíz. Documentado en README, sección "Workflow: this repo requires PRs".
**Esto NO aplica a proyectos generados** (`template/` sigue con push
directo a `main`, como documenta `template/AGENTS.md.jinja`) -- es
específico de este repo template.

## Qué sigue

Nada pendiente de la auditoría de esta sesión. Sin proyecto real generado
todavía -- el usuario planea empezarlo mañana. Recordatorio para esa
sesión: cualquier cambio a ESTE repo (el template) ahora necesita PR, no
push directo -- ver README. Los cambios dentro de un proyecto YA generado
siguen sin esa restricción.

## Bloqueado / pendiente de decisión

Ninguno.
