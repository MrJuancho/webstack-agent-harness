# ADR-0004: Capa de aplicación y feature de referencia

**Estado:** Aceptado
**Fecha:** 2026-11-13

## Contexto

El proyecto generado tenía tres capas (`domain`, `infra`, `http`) y ninguna feature que
las cruzara: el único código de dominio era `clamp`, y las únicas rutas, `/health` y un
`/api/v1/profile` de relleno. `AGENTS.md` ya hablaba de una "capa de aplicación" (de
donde entran el reloj y la aleatoriedad al dominio, Gate 10) y de una sección
"Convención de capas" que no existían. Un agente que empezaba un proyecto real no tenía
patrón que copiar: la primera feature fijaba la arquitectura sin guía, y nada impedía
que una ruta consultara la base directamente.

## Decisión

1. **Cuarta capa, `src/application/`**: casos de uso y los puertos que necesitan.
   Orquesta, no decide. Dependencias, de adentro hacia afuera:
   `domain <- application <- infra, http`. `infra` y `http` no se importan entre sí.
2. **Raíz de composición única, `src/composition.ts`**, fuera de las reglas de capa: el
   único archivo que conecta puertos con adaptadores reales, y el único que lee el reloj
   y genera ids.
3. **Feature de referencia `tasks`** (`POST` y `GET /api/v1/tasks`), con un archivo por
   capa. Es el patrón a copiar y está pensada para borrarse.
4. **`dependency-cruiser` exige las cuatro reglas**, y `scripts/verify-template.sh`
   prueba que cada una muerde plantando un import prohibido real (mismo principio que el
   fixture de Gate 10).

Detalles decididos al implementarla, verificados con `just setup && just gauntlet-full`
sobre un proyecto generado con Docker real:

- **`buildApp()` sin argumentos sigue funcionando**: `useCases` es opcional y por
  defecto usa `buildUseCases()` de `src/composition.ts`. Los hold-outs (que el agente no
  puede leer ni tocar) y la matriz de auth llaman a `buildApp` sin dependencias; un
  parámetro obligatorio los habría roto. Costo aceptado: `src/http/app.ts` importa la
  raíz de composición, en vez de que solo el punto de entrada lo haga.
- **Errores de dominio como valores (`Result`)**, no excepciones; la ruta los mapea a
  `422`. El `400` queda para lo que rechaza el esquema TypeBox.
- **`setErrorHandler` central** para que todo error salga con la forma `ErrorResponse`
  que documenta el contrato OpenAPI.
- **El dominio rechaza caracteres de control en el título.** Postgres no acepta NUL en
  `text`: sin esa regla, la entrada llegaba a la base y volvía como `500`.
- **`tasks.id` y `tasks.created_at` sin default en la base**: los decide la aplicación,
  para que el dominio se pruebe con valores fijos y el seed sea determinista (Gate 7).

## Consecuencias

- La mutación sigue acotada a `src/domain/**`. Los casos de uso no se mutan: no deben
  contener decisiones, y eso lo vigila el Reviewer (checklist, punto H), no un gate.
- Mover o renombrar una carpeta de capa obliga a actualizar `.dependency-cruiser.js` y
  los casos de `verify-template.sh`; si no, este último falla.
- Un layout por módulo (`src/modules/<x>/domain`) dejaría las reglas sin efecto: sus
  `path` son por capa. Adoptarlo requiere reescribir las reglas y el alcance de Stryker.
- Encontrado de paso y arreglado: `scripts/doctor.sh` moría en silencio (`set -e` +
  `pipefail` sobre un `grep` sin match) si `.copier-answers.yml` no traía `_commit`,
  antes de imprimir el aviso escrito para ese caso.
