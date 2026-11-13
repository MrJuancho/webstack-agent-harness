# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Plan acordado con el usuario: 4 mejoras al template, en orden, y recién
después soporte multi-base de datos. PR #14 mergeado con las dos primeras:

1. **Capa de aplicación + feature de referencia `tasks`** (ADR-0004):
   `src/application/`, `src/composition.ts`, reglas de capa en
   dependency-cruiser, y `verify-template.sh` prueba que cada regla muerde.
2. **`requireAuth` verifica un JWT real y falla cerrado** (ADR-0005): sin
   `JWT_SECRET` (>= 32 chars) el servidor no arranca; `worktree-env.sh` lo
   genera en `.env.local`; `just dev-token` emite uno de prueba.

Verificado (logs leídos): `Verify Template` verde en el PR; `Verify E2E`
verde sobre `main` (`_commit=efdbb1b`), hold-outs sellados incluidos.

Notas: en CI depcruise colorea su salida (quitar ANSI antes de un grep);
en esta máquina (WSL) falta `pg_isready` -- instalar `postgresql-client`
para correr en local el gauntlet de un proyecto generado.

## Qué sigue

3. Básicos de producción: logging (hoy `logger: false`), apagado ordenado,
   validación de variables de entorno al arrancar, Dockerfile de la app.
   (El manejador central de errores ya entró en el PR #14.)
4. Renovate o Dependabot, en este repo y en los proyectos generados.
5. Después, multi-base de datos: primero aislar los comandos de Postgres
   de los gates detrás de una interfaz, luego UNA base más.

## Bloqueado / pendiente de decisión

Decisión del usuario (ADR-0005): `requireAuth` corre en `preHandler`, tras
validar el esquema -- sin token y con cuerpo inválido responde 400, no 401.
Moverlo a `onRequest` toca Gate 4, la constitución y quizá los hold-outs.
