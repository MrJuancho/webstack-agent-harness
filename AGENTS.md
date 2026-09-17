# AGENTS.md — Protocolo Operativo del Harness

Este repositorio opera bajo una arquitectura de **falla cerrada (fail-closed)**. Ninguna tarea se considera completa si no existe verificación reproducible de código (exit 0).

Antes de explorar el repo para reconstruir en qué quedó el trabajo, lee [`docs/progress.md`](./docs/progress.md) — es el handoff entre sesiones (en qué quedó la anterior, qué sigue, qué está bloqueado). Se sobrescribe en cada sesión, no se acumula; al terminar la tuya, actualízalo con el estado real, no lo dejes con el de la sesión pasada.

Para decisiones ya tomadas y su porqué (no solo el qué), ve [`docs/adr/`](./docs/adr/) antes de reabrir un debate ya resuelto o de revertir algo sin entender por qué se hizo así.

---

## 1. Jerarquía de Verificación (`justfile`)

Todo agente debe ejecutar el nivel adecuado según el ciclo de trabajo:

| Nivel | Comando | Cuándo Ejecutar | Alcance Técnico |
|---|---|---|---|
| **Nivel 1** | `just gauntlet-fast` | Tras cada edición de archivo | Gitleaks (staging), `tsc --noEmit`, ESLint y Vitest unitario. |
| **Nivel 2** | `just gauntlet` | Antes de commitear cambios | Aislamiento arquitectónico (depcruise), PostgreSQL tmpfs, deriva DDL (Gate 2), reversibilidad Up/Down (Gate 1), matriz de auth (Gate 4) y detector N+1 (Gate 6). |
| **Nivel 3** | `just gauntlet-full` | Antes de solicitar revisión/PR | Property tests con arbitrarios de dominio real, Schemathesis (Gate 3), semillas deterministas (Gate 7), hold-outs SHA-256 (Gate 5) y mutación sobre diff (Stryker). |
| **Nivel 4** | `just audit` | Tareas programadas / auditoría | Mutación exhaustiva de todo el dominio. |

---

## 2. Los 8 Gates de Seguridad

1. **Gate 1 (Migraciones Reversibles):** Todo `.sql` requiere su `.down.sql`. El rollback no debe dejar residuos DDL en `pg_dump`.
2. **Gate 2 (Schema Drift):** Modificaciones en `src/infra/db/schema.ts` requieren correr `just db-generate`. No puede haber discrepancia entre TypeScript y SQL.
3. **Gate 3 (Contratos OpenAPI):** Todo endpoint debe declarar esquemas TypeBox completos, incluyendo códigos de error esperados (ej. `401 Unauthorized`). Schemathesis no tolera respuestas no documentadas.
4. **Gate 4 (Matriz de Autenticación):** Toda ruta en Fastify debe incluir `preHandler: [requireAuth]` o declarar explícitamente `config: { isPublic: true }`.
5. **Gate 5 (Hold-Out Tests):** La suite `tests/holdout/` y su firma `.holdout.sha256` son de **solo lectura**. Si un agente altera aserciones para forzar un pase, el gate aborta. El sello solo se actualiza manualmente mediante `just seal-holdouts`.
6. **Gate 6 (Detector N+1):** Las consultas relacionadas deben resolverse vía joins o batching (`inArray`). Iterar consultas dentro de bucles sobrepasa el límite de `assertMaxQueries` y rompe el gate.
7. **Gate 7 (Semillas Deterministas):** Prohibido usar `Date.now()`, `new Date()` sin fecha fija, o UUIDs dinámicos en `seed.ts`. Las firmas SHA-256 de volcados consecutivos deben ser idénticas.
8. **Gate 8 (Prevención de Secretos):** Gitleaks escanea el área de preparación en cada ciclo rápido.

---

## 3. Las 4 Capas de Enforcement

1. **Capa 1 (Hooks del Agente):**
   - `PreToolUse`: Bloquea cualquier intento de escritura o borrado sobre `tests/holdout/` y `.holdout.sha256`. Falla cerrado si el input no es parseable.
   - `Stop`: Impide que el agente declare terminada la sesión si `just gauntlet-fast` arroja error.
   - `PostToolUse`: Da feedback rápido de ESLint tras cada `Edit`/`Write` sobre un `.ts`, sin bloquear nada (ver tabla de fail-closed/fail-open abajo).
2. **Capa 2 (Git Pre-Commit Hook):** Ejecuta `just gauntlet-fast` antes de registrar cualquier commit en local.
3. **Capa 3 (CI / GitHub Actions):** Ejecuta `just doctor` y `just gauntlet-full` en contenedores limpios para cada push o PR.
4. **Capa 4 (Branch Protection):** La rama `main` exige que el check `Level 3 Pre-Merge Gate` pase en verde antes de autorizar merge.

### Qué falla cerrado y qué falla abierto

**Los componentes de seguridad fallan CERRADOS; los de conveniencia fallan
ABIERTOS.** No es teórico: el hallazgo fundacional de este principio en
este mismo repositorio fue que `guard-holdouts.sh` y `stop-gate.sh` usaban
`exit 1` en vez de `exit 2` -- en Claude Code, solo `exit 2` bloquea un
`PreToolUse`/`Stop`, así que ambos llevaban desde su creación sin bloquear
nada de verdad, pese a que el código "parecía" correcto. Antes de dar por
bueno un componente nuevo, pregúntate qué hace cuando le falta una
dependencia o el evento no puede resolverse, no solo cuando todo está
instalado -- y **provócalo en vivo** al menos una vez; un componente nunca
verificado en el entorno real no cuenta como confirmado.

| Hook | Clasificación | Por qué |
|---|---|---|
| `PreToolUse` (`guard-holdouts.sh`) | Seguridad -- falla CERRADO | Si no se puede determinar la ruta del archivo por cualquier motivo (JSON malformado, campo ausente, `jq` mismo ausente), bloquea por defecto (`exit 2`). |
| `Stop` (`stop-gate.sh`) | Seguridad -- falla CERRADO | Es la última revisión antes de que termine el turno; si `just`/`CLAUDE_PROJECT_DIR` faltaran y esto fallara abierto, un turno entero podría cerrarse sin que `gauntlet-fast` corriera ni una vez. |
| `PostToolUse` (`lint-on-edit.sh`) | Conveniencia -- falla ABIERTO | Si falta `jq`, `pnpm`, o no se puede resolver la ruta, simplemente no da feedback -- nunca debe impedir que una edición ya aplicada quede en pie. Un hallazgo real de ESLint sí se reporta (`exit 2`, no bloqueante para `PostToolUse` porque la herramienta ya corrió, solo aparece como contexto inmediato). |
| CI `doctor` | Seguridad -- falla CERRADO por diseño de dependencia | Si `just doctor` falla (falta una herramienta en el runner), el resto del workflow no debería continuar como si hubiera pasado. |

---

## 4. Roles Operativos y Aislamiento con Git Worktrees

Para evitar colisiones de dependencias, bloqueo de puertos y sobrescritura de ramas locales:

### Rol: Generator (Desarrollo Activo)

- Trabaja en el directorio raíz del repositorio.
- Opera siempre en una rama de feature (`git checkout -b feature/<nombre>`).
- Debe correr `just gauntlet-fast` continuamente y commitear únicamente con `just gauntlet` en verde.

### Rol: Reviewer (Auditoría de Código)

- **Nunca** inspecciona código dentro del mismo working tree del generador.
- Despliega un entorno desacoplado mediante:
  ```bash
  just review-start <rama-a-revisar>
  ```
- Al terminar, libera el worktree con `just review-clean`.

### Regla de concurrencia: un árbol de trabajo, un escritor

`generator` puede seguir usando el árbol principal (es el único rol con
permiso de escritura; nadie más compite por ese árbol mientras trabaja
solo). Un rol de verificación (`reviewer`, o cualquier otro que se agregue
después) **nunca** debe inspeccionar un árbol que otro proceso pueda estar
modificando al mismo tiempo -- si dos roles de verificación corren en
paralelo entre sí, o junto con `generator`, cada uno necesita su propio
`git worktree` vía `just review-start <nombre>` / `just review-clean`. Esto
es intencionalmente independiente de cualquier IDE o entorno de agentes en
particular: se apoya solo en `git worktree`, así que funciona igual sin
importar qué herramienta orquesta las sesiones paralelas.

Si un rol de verificación detecta a medio trabajo que el árbol cambió bajo
sus pies (una rama distinta, archivos apareciendo o desapareciendo sin
haberlos tocado), debe abortar y reportarlo -- nunca seguir adelante con
resultados medidos sobre un estado inconsistente como si fueran confiables.
