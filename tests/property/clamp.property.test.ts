import { describe, it } from 'vitest';
import fc from 'fast-check';
import { clamp } from '../../src/domain/clamp.js';

describe('clamp (invariantes de propiedad)', () => {
  it('el resultado siempre se encuentra dentro del intervalo [min, max]', () => {
    fc.assert(
      fc.property(
        fc.integer(),
        fc.integer(),
        fc.integer(),
        (val, a, b) => {
          const min = Math.min(a, b);
          const max = Math.max(a, b);
          const result = clamp(val, min, max);
          return result >= min && result <= max;
        }
      ),
      { numRuns: 1000 }
    );
  });
});
