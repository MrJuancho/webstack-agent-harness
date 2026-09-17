# ADR-0001: Los hooks de seguridad de Claude Code deben salir con código 2, nunca 1

**Estado:** Aceptado
**Fecha:** 2026-09-16

## Contexto

`guard-holdouts.sh` (Capa 1, `PreToolUse`) y `stop-gate.sh` (Capa 1, `Stop`)
existían desde la creación del harness y, a simple lectura del código,
parecían fail-closed: ambos usaban `exit 1` en cada rama de fallo, con
mensajes claros de "ACCESO DENEGADO" / "ERROR" a stderr.

Al revisar la documentación oficial de Claude Code
(https://code.claude.com/docs/en/hooks) se confirmó que **solo el código de
salida 2 bloquea un evento `PreToolUse` o `Stop`** -- el código 1 se trata
como un error no bloqueante, y la acción original procede de todos modos.
Se verificó en vivo, sin ambigüedad: se intentó una edición real sobre
`tests/holdout/security-invariants.holdout.test.ts` con el hook en su
versión original (`exit 1`) y la edición se aplicó sin obstáculo. Tras
cambiar ambos scripts a `exit 2`, el mismo intento fue bloqueado con el
mensaje esperado.

Es decir: Gate 5 (protección anti-tampering de hold-outs) y el gate de
`Stop` (bloquear el cierre de turno con `gauntlet-fast` en rojo) llevaban
desde su creación sin bloquear absolutamente nada. El resto del harness
(gates 1-4, 6-8, capas 2-4) nunca dependió de estos dos hooks para
funcionar, así que la exposición real fue acotada -- pero es exactamente
la clase de defecto que este proyecto existe para prevenir: un componente
de seguridad que parece correcto y no lo es, nunca ejercitado en el
entorno real hasta ahora.

## Decisión

1. Todo hook de Claude Code en este repositorio que exista para **bloquear**
   una acción (`PreToolUse`, `Stop`, o cualquier evento futuro que la
   documentación oficial liste como bloqueable) debe salir con código **2**
   en cada rama de fallo, nunca con 1 ni con `set -e` implícito que pueda
   producir otro código.
2. Todo hook de este tipo se invoca en `.claude/settings.json` vía
   `${CLAUDE_PROJECT_DIR}` (nunca una ruta relativa) seguido de `|| exit 2`,
   para que una falla en la invocación misma (script movido, permisos,
   binario ausente) también resulte en bloqueo, no en un código de salida
   distinto que se trate como advertencia no bloqueante.
3. Antes de dar por bueno un hook de seguridad nuevo, se prueba en vivo al
   menos una vez -- se provoca la condición que debería bloquear y se
   confirma que efectivamente bloquea. No basta con que el código "se vea"
   fail-closed.

## Consecuencias

- `guard-holdouts.sh` y `stop-gate.sh` corregidos y verificados en vivo
  (commit `c42d4d5`).
- `AGENTS.md`, sección "Qué falla cerrado y qué falla abierto", documenta
  la clasificación resultante y remite a este ADR como el incidente que la
  originó.
- Un hook de conveniencia nuevo (`lint-on-edit.sh`, `PostToolUse`) usa
  `exit 2` con un significado distinto y deliberado: en `PostToolUse` la
  herramienta ya corrió, así que "bloquear" no aplica -- ahí `exit 2` solo
  sirve para que el hallazgo se muestre a Claude como contexto inmediato en
  vez de quedar solo en el log de depuración. No se debe inferir de este
  ADR que todo `exit 2` implica bloqueo; el significado depende del evento,
  y se verifica contra la documentación oficial, nunca por analogía entre
  hooks.
