# ADR-0003: Migración a Copier -- reemplaza ADR-0002

**Estado:** Aceptado
**Fecha:** 2026-09-17

## Contexto

[ADR-0002](./0002-instanciacion-clon-no-template.md) (2026-09-16) eligió clon +
`git init` sobre un motor de plantillas, explícitamente porque en ese momento no
existía la maquinaria de sustitución de variables, y porque el harness parecía
suficientemente estable como para no necesitar propagar mejoras a proyectos ya
generados. Esa misma ADR ya anticipaba su propia revisión: "si este harness cambia
con la frecuencia suficiente... esta decisión debe revisarse."

Un día después, el usuario señaló explícitamente el motivo real: quiere que mejoras al
harness (como el fix de `exit 1` vs `exit 2` de ADR-0001, encontrado el mismo día que
se escribió ADR-0002) lleguen a proyectos ya generados sin portarlas a mano una por
una -- exactamente el problema que `gauntlet-template` (la referencia de este mismo
autor para su stack Python) ya resuelve con Copier y `copier update`.

## Decisión

Se adopta [Copier](https://copier.readthedocs.io/), replicando la estructura de
`gauntlet-template`: `copier.yml` en la raíz con `_subdirectory: template`, todo el
contenido del proyecto generado bajo `template/`, y la raíz de este repo reservada para
la gestión del template en sí (`docs/adr/`, `docs/progress.md`, este README).

Variables: `project_name`, `package_name` (kebab-case, deriva de `project_name`),
`db_name` (snake_case, deriva de `package_name`), `github_owner` (default `MrJuancho`).

Detalles verificados con una corrida real de `copier copy` + `just setup` + `just
gauntlet` en un proyecto generado (no solo revisión de código):

1. **`justfile` no lleva sufijo `.jinja`.** `just` usa su propia sintaxis
   `{{variable}}` para parámetros de receta (`review-start BRANCH="HEAD":` /
   `{{BRANCH}}`), que colisiona con los delimitadores de Jinja. Se copia literal; sus
   dos sustituciones reales (`__PACKAGE_NAME__`, `__DB_NAME__`) se resuelven con `sed`
   en `_tasks`, después de copiar. Mismo patrón, mismo motivo, que
   `gauntlet-template`.
2. **`copier copy` no inicializa git por su cuenta.** `just install-hooks` (parte de
   `just setup`) necesita `.git/hooks/`, que no existe en un directorio recién
   generado sin `.git`. Sin `git init` como primer `_tasks`, `just setup` fallaba en
   `install-hooks` con "No such file or directory" -- encontrado corriendo `just
   setup` de verdad en un proyecto generado, no inferido del código. `_tasks` ahora
   incluye `git init -q || true` como primer paso.
3. **Nombres de bases de datos efímeras hardcodeados con "webstack".**
   `scripts/test-migrations-reversible.sh` y `scripts/test-seed-determinism.sh` tenían
   `TEST_DB="webstack_migrate_rev_test"` / `"webstack_seed_test"` -- inocuo
   funcionalmente (son bases descartables, nunca colisionan entre proyectos porque
   cada uno usa su propio contenedor Docker Compose), pero seguían nombrando al
   harness original. Renombrados a `_gauntlet_migrate_rev_test` /
   `_gauntlet_seed_test`: nombres genéricos, no necesitan Jinja.
4. **`docs/webstack-agent-harness-spec.{html,pdf}` no se versiona dentro de
   `template/`.** Se regenera como `docs/spec.html`/`.pdf` vía `scripts/generate-pdf.sh.jinja`
   (con `{{ project_name }}` en el título) como tarea de `_tasks`, para no mantener dos
   copias del mismo contenido en dos formatos.
5. **`dunamai` (la librería de versionado de Copier) fallaba contra el tag
   `v1.0.0-harness`** de este mismo repositorio -- no es PEP 440 válido, y Copier por
   defecto hace checkout del tag más reciente si no se le pasa `--vcs-ref`. Resuelto
   taggeando el commit de esta migración como `v0.1.0` (PEP 440 válido, y más cercano
   a HEAD que el tag viejo, así que `git describe`/`dunamai` lo encuentran primero) en
   vez de borrar el tag viejo -- se conserva como historia.

## Consecuencias

- `AGENTS.md` (ahora `template/AGENTS.md.jinja`) y `docs/progress.md` (ahora
  `template/docs/progress.md`, vacío, `_skip_if_exists`) migraron a `template/`. La
  raíz del repo ya no tiene su propio `AGENTS.md` -- coincide con el patrón de
  `gauntlet-template`, que tampoco lo tiene a nivel raíz.
- Ya no existe una suite de meta-tests que verifique el mecanismo del template en sí
  (lo que sí tiene `gauntlet-template` en su `tests/` de raíz, con `pyproject.toml`
  propio). Se verificó a mano, una vez, con una corrida real de `copier copy` seguida
  de `just setup` y `just gauntlet` completos -- no hay garantía de que un cambio
  futuro al template no rompa la generación hasta que se repita esa verificación a
  mano, o hasta que se construya esa infraestructura de meta-tests.
- Este commit queda taggeado `v0.1.0` (hallazgo 5 arriba); versiones futuras del
  template deberían seguir taggeando cada cambio significativo para que `copier
  update` tenga una referencia de versión útil.
