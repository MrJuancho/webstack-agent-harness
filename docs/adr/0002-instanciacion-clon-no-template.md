# ADR-0002: Nuevos proyectos se instancian clonando y reiniciando git, no vía GitHub template

**Estado:** Aceptado
**Fecha:** 2026-09-16

## Contexto

Este repositorio es un harness reutilizable, análogo en propósito a
[gauntlet-template](https://github.com/MrJuancho/gauntlet-template) para el
stack Python/datos de este mismo autor. A diferencia de ese template,
`webstack-agent-harness` no está construido con un motor de plantillas
(`copier`, `cookiecutter`) ni pensado para usarse como "GitHub template
repository" con sustitución automática de placeholders.

Dos formas de instanciar un proyecto nuevo a partir de este repo:

1. **GitHub template repository**: marcar el repo como template y usar
   "Use this template" / `gh repo create --template`, lo que crea un repo
   nuevo sin historial de git compartido, pero tampoco sin ningún mecanismo
   de sustitución de nombres/placeholders -- cada referencia a
   `webstack-agent-harness`/`webstack_dev` habría que cambiarla a mano de
   todos modos.
2. **Clonar y reiniciar `.git`**: `git clone`, `rm -rf .git && git init`,
   apuntar a un remoto nuevo.

## Decisión

Se elige la opción 2. Dado que ninguna opción evita el paso manual de
renombrar referencias (`package.json`, `docker-compose.yml`, badges de
`README.md`, título del spec doc, `tests/holdout/` con invariantes reales),
la ventaja real de "GitHub template" (evitar ese renombrado) no aplica
aquí -- y la opción 2 es más simple de razonar, no depende de una
configuración de GitHub que hay que recordar mantener activa, y dado que
este repositorio no cambiará frecuentemente no requiere `copier update` ni
ningún mecanismo de propagación de cambios que sí es la razón principal por
la que `gauntlet-template` sí adoptó un motor de plantillas propio.

## Consecuencias

- El checklist de renombrado (`docs/progress.md`, sección "Qué sigue", al
  momento de este ADR) se ejecuta a mano justo después del clon, no antes.
- Si en el futuro este harness cambia con la frecuencia suficiente para que
  valga la pena propagar mejoras a proyectos ya instanciados (el problema
  que `copier update` resuelve en `gauntlet-template`), esta decisión debe
  revisarse -- no hay ningún mecanismo hoy para que un proyecto ya clonado
  reciba actualizaciones de este harness sin repetir el trabajo a mano.
- Este repositorio **no** debe marcarse como GitHub template repository
  (Settings → Template repository) mientras esta decisión siga vigente, en
  caso de que alguien confunda su existencia con una invitación a usar esa
  vía en su lugar.
