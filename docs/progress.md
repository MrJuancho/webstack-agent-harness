# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

PR #8 (e2e contra Docker real + arreglos de mutación) y PR #9 mergeados.
PR #9: `Verify E2E` NUNCA había pasado en CI (0 de 42 corridas) --
`verify-e2e.yml` no instalaba gitleaks, que `doctor.sh` exige. Confirmado
contra el log real de CI, no inferido. Además, en el `ci.yml` GENERADO,
`gitleaks/gitleaks-action@v2` corta con exit 1 antes de instalar nada si el
dueño del repo es una Organization sin `GITLEAKS_LICENSE` (de pago) --
verificado en el código fuente de la action. Era también el ÚNICO escaneo
de secretos real en CI: Gate 8 (`protect --staged`) escanea 0 commits en un
checkout limpio. Reemplazado por binario fijado 8.24.3 + paso explícito
`gitleaks git --redact --verbose .` sobre toda la historia.

Verificado: `Verify E2E` en verde sobre `main` (`_commit=a3a7087`, log crudo
leído). El escaneo nuevo, local sobre un proyecto generado: historia limpia
exit 0, clave AWS plantada exit 1, sigue exit 1 tras borrar el archivo.

## Qué sigue

Probar el `ci.yml` generado corriendo en GitHub de verdad: generar un
proyecto, empujarlo a un repo privado temporal, leer el log crudo; luego un
PR con un secreto falso que el paso "Secret scan" debe bloquear. Pendiente
porque crear el repo requiere permiso explícito del usuario (el modo auto
lo bloqueó). Borrarlo después requiere el scope `delete_repo` en `gh`.

Menor: las actions fijadas en `@v3`/`@v4` corren en Node 20 (deprecado,
solo warning hoy).

## Bloqueado / pendiente de decisión

Permiso para crear el repo temporal de prueba de CI.
