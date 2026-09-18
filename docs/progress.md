# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Incidente real: `copier copy` sin `--vcs-ref` servía un snapshot de ~30
commits (tag `v0.1.0`) a cualquiera, por tags viejos que shadoweaban
`main`. Borrar los tags (con confirmación del usuario) arregló el
síntoma, NO el mecanismo -- el día que este repo vuelva a tener tags (uso
maduro y deseable de una plantilla versionada), la misma trampa vuelve.
La protección durable, más barata: este template NUNCA escribía
`.copier-answers.yml` (le faltaba el archivo estándar
`{{ _copier_conf.answers_file }}.jinja` que Copier exige que la propia
plantilla provea) -- `copier update` estaba roto para TODO proyecto
generado desde siempre, confirmado a mano. Arreglado. `doctor.sh` ahora
compara `_commit` contra el HEAD remoto real de la plantilla (advierte
por defecto, falla con `DOCTOR_STRICT_TEMPLATE_FRESHNESS=1`).
`scripts/verify-e2e.sh` reescrito para clonar el remoto real sin
`--vcs-ref` (antes probaba el working tree local, el camino que no
habría atrapado el incidente) y afirmar que el `_commit` resultante
coincide con el HEAD remoto real. README raíz: recomienda `--vcs-ref`
explícito siempre; nunca borrar tags como arreglo futuro (rompe
`copier update` de quien ya generó contra ellos).

Los tres arreglos de PR #8 (`pg_isready` real, `db-reset` con `down -v`,
`doctor` fail-closed) quedaron re-confirmados contra el branch local --
las corridas anteriores habían sido, sin darme cuenta, contra el
snapshot viejo. Verificados de nuevo, en verde.

## Qué sigue

Mergear PR #8. Correr `verify-e2e.sh` real (remoto pusheado) antes.

## Bloqueado / pendiente de decisión

Ninguno.
