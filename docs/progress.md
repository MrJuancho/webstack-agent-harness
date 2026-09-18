# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

Error real de reporte (no del código): dije que los 3 arreglos de PR #8
estaban re-confirmados, pero la evidencia que mostré venía de un proyecto
generado contra `main`/`757da37` (anterior al merge de #8), no contra el
branch real -- el usuario lo detectó por las líneas de log exactas
(`pg_isready` contra `/var/run/postgresql` en vez de `127.0.0.1:PG_PORT`;
`db-reset` sin `docker compose down -v`). Re-verificado de cero contra
`_commit` = tip real de `fix/e2e-generation-bugs`: los 3 arreglos SÍ
funcionan (output crudo de `db-up`/`db-reset` inspeccionado directamente,
no un resumen). Lección: nunca confiar en una señal agregada sin leer la
evidencia cruda que resume.

Dos hallazgos nuevos del usuario, ambos arreglados y verificados:

1. El "100.00%" de Stryker escondía que 4 de 17 mutantes instrumentados
   nunca corrieron (ignorados vía `// Stryker disable`, justificados por
   Gate 9, pero el score no lo decía). `scripts/run-mutation.sh` (nuevo,
   envuelve `stryker run` en `mutate:diff` y `mutate:full`) lee el reporte
   JSON y siempre imprime cuántos fueron ignorados, con archivo:línea y
   motivo -- pase o falle la corrida. Requiere reporter `'json'` en
   `stryker.config.mjs` (ya agregado).
2. `just audit` reutilizaba el `.stryker-tmp/incremental.json` de
   `mutate:diff` corrido segundos antes en la misma sesión -- contradice
   la promesa de "exhaustivo". `mutate:full`/audit ahora usa un archivo
   separado (`.stryker-tmp/incremental-audit.json`, vía `--full` en
   `run-mutation.sh`). Confirmado a mano: tras un `audit`, un `mutate:diff`
   inmediato NO reusa su caché (corre completo), y `mutate:diff` sigue
   reusando su PROPIA caché entre corridas propias.

## Qué sigue

Commitear y pushear estos dos arreglos de mutación a `fix/e2e-generation-bugs`
(PR #8 sigue abierto). Mergear PR #8 solo con confirmación explícita del
usuario -- no asumir.

## Bloqueado / pendiente de decisión

Ninguno.
