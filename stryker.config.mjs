// @ts-check
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: 'pnpm',
  reporters: ['html', 'clear-text', 'progress'],
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  thresholds: {
    high: 90,
    low: 85,
    break: 80,
  },
  mutate: [
    'src/domain/**/*.ts',
    '!src/**/*.d.ts',
  ],
  vitest: {
    configFile: 'vitest.config.ts',
  },
};
