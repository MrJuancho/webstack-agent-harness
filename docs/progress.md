# Progress -- handoff entre sesiones

<!--
Se SOBRESCRIBE, no se acumula. Límite duro: 40 líneas. El historial de qué
cambió y por qué vive en `git log`, y en `docs/adr/` -- no aquí.
-->

## En qué quedó la última sesión

**Hallazgo crítico, fuera del código:** el comando de Quick Start de este
mismo README (`copier copy` sin `--vcs-ref`) estaba sirviendo un snapshot
de ~30 commits de antigüedad (tag `v0.1.0`, la primera conversión a
Copier) a CUALQUIERA que lo corriera -- Copier usa el tag más reciente por
defecto si el repo tiene tags, y este tenía dos (`v0.1.0`, `v1.0.0-harness`,
el segundo incluso más viejo, de antes de existir `copier.yml`). Ningún
fix de esta sesión ni de las anteriores llegaba a un proyecto recién
generado así, incluyendo el aislamiento por worktree completo. Confirmado
reproduciendo el comando exacto contra GitHub real. Ambos tags borrados
(local y remoto, con confirmación explícita del usuario) -- verificado que
`copier copy` sin ref ahora cae en `main` HEAD ("No git tags found in
template; using HEAD as ref") y que `just setup` corre en verde con el
contenedor nombrado correctamente (`<package>-<hash>-postgres-1`).

Además, en la rama `fix/e2e-generation-bugs` (PR #8, pendiente de
mergear): `db-up` tenía un wait a Postgres que no esperaba de verdad
(intento único + `sleep 2` + seguir de largo); `db-reset` reutilizaba el
contenedor de una corrida anterior ("efímero" era falso); `doctor.sh`
solo advertía (⚠) si faltaba `.env.local`. Los tres arreglados y
verificados con Docker real. Nuevo `scripts/verify-e2e.sh` -- ojo: no
habría atrapado el bug de los tags, corre desde un checkout local, no vía
`copier copy` contra el remoto real; tenerlo en cuenta si se vuelve a
taggear este repo.

## Qué sigue

Mergear PR #8 (`fix/e2e-generation-bugs`).

## Bloqueado / pendiente de decisión

Ninguno.
