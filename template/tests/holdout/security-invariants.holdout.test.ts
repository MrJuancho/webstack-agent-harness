import { describe, it, expect } from 'vitest';
import { clamp } from '../../src/domain/clamp.js';

describe('Gate 5: Hold-Out Invariants (Suite Protegida)', () => {
  it('el clamping estricto no debe permitir valores fuera de los límites bajo ninguna circunstancia', () => {
    expect(clamp(Number.MAX_SAFE_INTEGER, 0, 100)).toBe(100);
    expect(clamp(Number.MIN_SAFE_INTEGER, -100, 0)).toBe(-100);
    expect(clamp(50, 50, 50)).toBe(50);
  });

  it('rechaza intervalos invertidos de forma determinista', () => {
    expect(() => clamp(10, 100, 0)).toThrow();
  });
});
