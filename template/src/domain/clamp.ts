export function clamp(value: number, min: number, max: number): number {
  if (min > max) {
    throw new RangeError(`min (${min}) cannot be greater than max (${max})`);
  }
  // Stryker disable next-line EqualityOperator: cuando value === min, "value" y
  // "min" son el mismo número -- devolver uno u otro no cambia la salida
  // observable, así que el mutante `<=` es equivalente de verdad, no un hueco
  // de test. Ver AGENTS.md, Gate 9.
  if (value < min) {
    return min;
  }
  // Stryker disable next-line EqualityOperator: mismo caso que arriba con
  // value === max -- "value" y "max" son el mismo número, el mutante `>=` es
  // igual de equivalente.
  if (value > max) {
    return max;
  }
  return value;
}
