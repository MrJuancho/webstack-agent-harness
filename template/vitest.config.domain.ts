import { defineConfig } from 'vitest/config';

// Suite de dominio: SOLO src/domain/**/*.test.ts. Sin globalSetup, sin
// setupFiles, sin nada que abra una conexión o levante infraestructura --
// si un test de dominio necesita la base de datos, es la lógica (o el
// test) lo que está mal ubicado, no esta config. Ver AGENTS.md, sección
// "Convención de capas".
//
// Usada por `just test-domain` (Nivel 1, corre en cada edición) y por
// stryker.config.mjs (`vitest.configFile`) para que cada mutante corra
// solo esta suite en vez de pagar el costo del suite completo con
// Postgres.
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/domain/**/*.test.ts'],
  },
});
