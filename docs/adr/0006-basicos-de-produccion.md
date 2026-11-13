# ADR-0006: Básicos de producción -- configuración validada, logs, apagado e imagen

**Estado:** Aceptado
**Fecha:** 2026-11-13

## Contexto

El proyecto generado pasaba todos los gates pero no estaba listo para desplegarse:

- Cada archivo leía `process.env.X ?? default` por su cuenta (cuatro copias de la URL de
  Postgres). `PORT=abc` se convertía en `NaN`, y producción sin `DATABASE_URL` caía en
  silencio al Postgres local por defecto.
- `logger: false`: ningún log, ni de errores.
- Sin manejo de `SIGTERM`: un despliegue cortaba los requests en curso.
- Sin `Dockerfile`, y la app solo corría con `tsx` (una devDependency).

## Decisión

1. **Configuración en un solo lugar, validada al arrancar** (`src/infra/config.ts`).
   Informa todos los problemas juntos. Con `NODE_ENV=production`, `DATABASE_URL` es
   obligatorio. `readDatabaseConfig` (migrate, seed, cliente) no exige `JWT_SECRET`.
2. **Punto de entrada `src/main.ts`**: valida la configuración y recién entonces importa
   el resto con `import()` dinámico. Hace falta porque `src/infra/db/client.ts` abre su
   pool al importarse: con un import estático corría antes que la validación, y el
   proceso moría con el primer problema y un stack trace. Lo encontró `just image-check`
   en su primera corrida.
3. **Logs JSON por stdout** (pino, vía Fastify), nivel `LOG_LEVEL`. `buildApp()` sin
   `logLevel` sigue en silencio, para los tests.
4. **Apagado ordenado** en `src/http/server.ts`: ante `SIGTERM`/`SIGINT`, `app.close()`,
   después `closeResources()` (pool de Postgres), `exit 0`; `exit 1` si pasa de 10 s.
5. **`Dockerfile` multi-etapa**: compila con `tsc` (`tsconfig.build.json`), instala solo
   dependencias de producción en una etapa aparte, corre `node dist/main.js` sin root.
6. **`just image-check`, dentro de `just gauntlet-full`**: construye la imagen y la
   prueba corriendo -- falla cerrado sin configuración, responde `/health`, no es root,
   corre las migraciones compiladas, y sale con `0` ante `SIGTERM`.

Fuera de alcance, a propósito: endpoint de readiness con chequeo de base, métricas,
trazas, y logs legibles en desarrollo (`pino-pretty`).

## Consecuencias

- `just gauntlet-full` construye una imagen Docker. Con caché tarda segundos; en un
  runner limpio de CI suma el `pnpm install` y la compilación dentro del build.
- Las migraciones pasan a ser un paso explícito del despliegue
  (`node dist/infra/db/migrate.js`), no parte del arranque.
- Una variable de entorno nueva se agrega en `src/infra/config.ts` con su test.
- Encontrado de paso y arreglado: `scripts/test-contracts.sh` arrancaba el servidor con
  `pnpm exec tsx` y al limpiar mataba solo ese envoltorio. El proceso `node` real
  quedaba vivo y dueño del puerto 3000; cada corrida siguiente fallaba al enlazar y
  Schemathesis auditaba en silencio el servidor VIEJO, con código viejo. Solo afectaba
  corridas locales repetidas (CI parte de un runner limpio). Ahora arranca `node`
  directo, lo detiene con `SIGTERM`, y falla si el servidor de esa corrida no está vivo.
