# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Aislamiento de Postgres entre worktrees del mismo proyecto generado.
Nuevo `scripts/worktree-env.sh`: deriva `PG_PORT` (20000 +
sha256(path-del-worktree) mod 10000, escape hatch si `PG_PORT` ya está en
el entorno) y `COMPOSE_PROJECT_NAME` (`<package_name>-<hash8>`), los
escribe en `.env.local` (gitignored, `just setup` regenera). Cambios:
`docker-compose.yml.jinja` (puerto dinámico, quitado `container_name:`
fijo -- colisionaba entre worktrees sin importar proyecto), `justfile`
(`set dotenv-filename := ".env.local"` + `dotenv-load`, quitado todo
`-p __PACKAGE_NAME__`), TS de infra/db (`dotenv` lee `.env.local` directo
para que `pnpm`/`vitest` fuera de `just` también apunten bien), `just
doctor` (falla cerrado si `PG_PORT` está ocupado por algo que no es el
contenedor de este worktree).

Verificado con Docker real: dos "worktrees" generados del mismo
`package_name` en paths distintos, `docker compose up -d` en ambos a la
vez (contenedores/redes/puertos distintos vía `docker ps`), `docker
compose down` en uno no tocó el otro. `scripts/verify-template.sh`
ampliado (genera el mismo proyecto dos veces, afirma `PG_PORT`/
`COMPOSE_PROJECT_NAME` distintos) y corrido en verde localmente. No había
lista de "gaps conocidos" en el repo sobre esto -- nada que borrar.

## Qué sigue

PR de este cambio en curso (ver README, "Workflow", para el flujo
obligatorio de PR de este repo). Una segunda feature (mutación acotada a
`src/domain/**`) se está preparando en una rama separada, apilada sobre
esta.

## Bloqueado / pendiente de decisión

Ninguno.
