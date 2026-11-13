# ADR-0007: Actualizaciones automáticas de dependencias con Dependabot

**Estado:** Aceptado
**Fecha:** 2026-11-13

## Contexto

Nada actualizaba las dependencias: ni las de este repo (las actions de sus workflows y
las dependencias con las que nace cada proyecto) ni las de los proyectos generados. El
PR #12 (actions sobre Node 20, ya deprecado) fue trabajo manual que apareció tarde.

## Decisión

1. **Dependabot, no Renovate.** Es un archivo (`.github/dependabot.yml`): no hay que
   instalar una app en cada repo generado ni darle acceso a un tercero. Renovate es más
   configurable, pero un proyecto recién generado tiene que quedar cubierto sin pasos
   extra.
2. **Proyectos generados** (`template/.github/dependabot.yml`): npm, GitHub Actions,
   la imagen del `Dockerfile` y la de `docker-compose.yml`. Semanal. Minor y patch van
   agrupados en un PR; cada major, en el suyo. Su CI corre `just gauntlet-full` en cada
   PR, así que un PR en verde ya pasó todos los gates.
3. **Este repo** (`.github/dependabot.yml`): los workflows propios y el `ci.yml` de la
   plantilla en un mismo PR, más `template/package.json` y `template/Dockerfile`.
4. **`template/package.json` deja de ser `.jinja`.** Dependabot solo reconoce un archivo
   con ese nombre exacto. Su única variable (el nombre) pasa a ser el placeholder
   `package-name-placeholder`, que un `sed` de `_tasks` reemplaza -- el mismo mecanismo
   que `__DB_NAME__` en el `justfile`. `verify-template.sh` comprueba que el reemplazo
   ocurrió.
5. **`Verify E2E` corre en los PRs que tocan dependencias de la plantilla.**
   `verify-template.sh` no instala ni corre el gauntlet, así que un bump se habría
   mergeado sin correr nunca. `scripts/verify-e2e.sh` acepta `E2E_TEMPLATE_SOURCE` para
   generar desde el checkout del PR. La corrida programada sigue yendo contra el remoto.
6. **Majors que no se proponen:** Node (imagen y `@types/node`: vive en tres lugares y
   se cambia a mano en los tres) y Postgres en los proyectos generados (un major no lee
   el directorio de datos del anterior).
7. **Mergear sigue siendo una decisión humana.** No hay auto-merge.

## Consecuencias

- No quedan cubiertos, y se actualizan a mano: la versión de Gitleaks fijada en los
  workflows, el campo `packageManager` (pnpm), la imagen `schemathesis:stable` y, en
  este repo, la imagen de Postgres de `template/docker-compose.yml.jinja` (sigue siendo
  `.jinja`; los proyectos generados sí la tienen cubierta).
- Que Dependabot lea un directorio de workflows distinto de `/` (acá,
  `/template/.github/workflows`) no está en su documentación oficial. Si no lo toma, el
  `ci.yml` de la plantilla se sincroniza a mano con los workflows de este repo.
- Las dependencias `0.x` (drizzle) llegan en el grupo de minor aunque puedan romper; el
  gauntlet es lo que lo detecta, y entonces ese PR se parte a mano.
