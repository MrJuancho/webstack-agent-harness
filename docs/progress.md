# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

PR #12 mergeado: todas las actions salen de Node 20 (deprecado) a majors
en node24 -- checkout v7, setup-node v7, pnpm/action-setup v6, setup-uv
v10.3.3, setup-just v4 (composite sobre setup-crate node24). Notas:

- setup-uv ya NO publica tag flotante de major (desde v8): `@v10` no
  resuelve y el job muere en "Set up job". Va fijado a versión exacta.
- `ci.yml` generado: sin `version:` en pnpm/action-setup. Desde v4, si
  difiere de `packageManager` el paso falla; ahora la única fuente de
  verdad es `package.json`. Los workflows de la raíz sí lo conservan (no
  hay package.json en la raíz).
- El token de `gh` no tiene scope `workflow`: push HTTPS de archivos en
  `.github/workflows/` a un repo nuevo es rechazado. Usar remoto SSH.

Verificado (logs crudos leídos): `Verify Template` y `Verify E2E` verdes
en la rama; `ci.yml` generado en repo privado temporal
(`MrJuancho/ci-smoke-20261113`, `_commit=425e062`): todo verde, pnpm
resolvió 9.15.4 desde `packageManager`, secret scan 1 commit, cero avisos
de Node 20. Repo temporal ya borrado.

## Qué sigue

Nada pendiente.

## Bloqueado / pendiente de decisión

Ninguno.
