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

Verificado (logs crudos leídos): `Verify E2E` verde sobre `main`
(`_commit=a3a7087`). `ci.yml` generado en GitHub real (repo privado temporal
`MrJuancho/ci-smoke-20261031`): push a `main` todo verde, "Secret scan"
escaneó 1 commit (Gate 8: 0); PR con clave AWS falsa falla en "Secret scan"
(`aws-access-token`, REDACTED) y el resto se salta.

## Qué sigue

Bug nuevo hallado en esa prueba: `_tasks` en `copier.yml` corre `git init`
pelado -- sin `init.defaultBranch=main` el proyecto nace en `master`, y el
`ci.yml` generado solo dispara en `main`: CI nunca corre. Arreglo probable:
`git init -q -b main` (git >= 2.28).

(El repo temporal de prueba ya fue borrado.) Menor: actions en `@v3`/`@v4` corren en Node 20 (deprecado, solo warning).

## Bloqueado / pendiente de decisión

Ninguno.
