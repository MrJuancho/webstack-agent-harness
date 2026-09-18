import { describe, it, expect } from 'vitest';
import { clamp } from './clamp.js';

describe('clamp (unit)', () => {
  it('retorna el valor si está dentro del rango', () => {
    expect(clamp(5, 0, 10)).toBe(5);
  });

  it('retorna min si el valor es menor', () => {
    expect(clamp(-5, 0, 10)).toBe(0);
  });

  it('retorna max si el valor es mayor', () => {
    expect(clamp(15, 0, 10)).toBe(10);
  });

  it('lanza RangeError si min > max', () => {
    expect(() => clamp(5, 10, 0)).toThrow(RangeError);
  });

  it('el mensaje de RangeError incluye min y max', () => {
    expect(() => clamp(5, 10, 0)).toThrow('min (10) cannot be greater than max (0)');
  });

  it('no lanza si min === max, y retorna ese valor', () => {
    expect(clamp(5, 5, 5)).toBe(5);
  });
});
