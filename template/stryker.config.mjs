// @ts-check
import os from 'node:os';

/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: 'pnpm',
  reporters: ['clear-text', 'progress'],
  testRunner: 'vitest',
  // perTest: cada mutante corre solo los tests que de verdad tocan la
  // línea mutada, no la suite entera. El acelerador más grande que hay,
  // y barato de mantener honesto porque la suite de dominio (ver
  // vitest.config.domain.ts) no tiene infraestructura que instrumentar.
  coverageAnalysis: 'perTest',
  // Sobre código puro, un mutante que no termina en ~2s es un bucle
  // infinito real (ej. condición de corte invertida), no lentitud
  // legítima -- no tiene caso esperarlo más.
  timeoutMS: 2000,
  // Sin Postgres en la suite de dominio no hay contención de conexiones
  // que evitar, así que puede usar todos los núcleos en vez del default
  // conservador pensado para suites con I/O.
  concurrency: os.cpus().length,
  // Solo sirve en local: el archivo de estado no sobrevive a un runner
  // de CI limpio (checkout nuevo en cada corrida). `just gauntlet-full`
  // en CI corre `mutate:diff` completo sin este archivo, que es el
  // comportamiento correcto -- ver AGENTS.md, "Mutación: qué se prueba y
  // qué no", antes de intentar cachear esto en CI sin necesitarlo de
  // verdad.
  incremental: true,
  incrementalFile: '.stryker-tmp/incremental.json',
  thresholds: {
    high: 90,
    low: 85,
    break: 90, // Falla si el mutation score es menor al 90% -- alcance acotado a dominio puro, así que el umbral puede ser exigente de verdad.
  },
  mutate: [
    'src/domain/**/*.ts',
    '!src/domain/**/*.d.ts',
    '!src/domain/**/*.test.ts',
  ],
  vitest: {
    configFile: 'vitest.config.domain.ts',
  },
};
