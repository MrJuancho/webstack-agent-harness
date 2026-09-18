# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

`verify-template.sh` pasaba en verde mientras el proyecto generado no
arrancaba contra Docker real: `db-up` tenía un "wait" a Postgres que no
esperaba de verdad (un intento + `sleep 2` + seguir de largo pasara lo
que pasara), `db-reset` reutilizaba el contenedor de una corrida anterior
(tmpfs sobrevive mientras no se pare -- "efímero" era falso), y
`doctor.sh` solo advertía (⚠, no bloqueaba) si faltaba `.env.local`. Los
tres arreglados y verificados con Docker real: wait ahora es un loop real
con `pg_isready -h 127.0.0.1 -p "$PG_PORT"` (nuevo requisito del host:
`postgresql-client`, agregado a doctor.sh y al CI), `db-reset` hace
`docker compose down -v` antes de levantar (confirmado a mano: una DB
marcador de una corrida NO sobrevive a la siguiente), y `doctor.sh` falla
(✖) si `.env.local` no existe.

Ese último fix exigía que el CI del proyecto generado corriera
`worktree-env.sh` antes de `just doctor` (no lo hacía, se habría roto).

Nuevo `scripts/verify-e2e.sh`: genera un proyecto real, corre `just setup
&& just gauntlet-full` contra Docker real, y afirma sobre el consumidor
(`.env.local` existe, el contenedor lleva el hash en el nombre, ningún
archivo tiene "5432" sin `PG_PORT` salvo el ejemplo comentado de
`.env.example`). Verde dos veces localmente (~60s c/u). Programado +
disparo manual en `verify-e2e.yml`, no en cada PR. No reproduje el bug #1
del reporte (`just setup` sí invoca `worktree-env.sh`, ya lo hacía).

## Qué sigue

PR de este cambio pendiente de crear y mergear.

## Bloqueado / pendiente de decisión

Ninguno.
