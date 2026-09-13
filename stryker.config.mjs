// @ts-check
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: 'pnpm',
  reporters: ['clear-text', 'progress'],
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  thresholds: {
    high: 90,
    low: 85,
    break: 90, // Falla si el mutation score es menor al 90%
  },
  mutate: [
    'src/domain/**/*.ts',
    '!src/domain/**/*.d.ts',
  ],
  vitest: {
    configFile: 'vitest.config.ts',
  },
};
