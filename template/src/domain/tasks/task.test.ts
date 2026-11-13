import { describe, it, expect } from 'vitest';
import { createTask, TASK_TITLE_MAX_LENGTH } from './task.js';

const context = {
  id: 'b0000000-0000-0000-0000-000000000001',
  now: new Date('2026-01-01T00:00:00.000Z'),
};

describe('createTask (unit)', () => {
  it('crea la tarea con el id y el instante recibidos, sin leer el entorno', () => {
    expect(createTask({ title: 'Escribir el ADR' }, context)).toEqual({
      ok: true,
      value: { id: context.id, title: 'Escribir el ADR', createdAt: context.now },
    });
  });

  it('recorta los espacios de los extremos del título', () => {
    expect(createTask({ title: '  Escribir el ADR \n' }, context)).toEqual({
      ok: true,
      value: { id: context.id, title: 'Escribir el ADR', createdAt: context.now },
    });
  });

  it('rechaza un título vacío', () => {
    expect(createTask({ title: '' }, context)).toEqual({
      ok: false,
      error: { kind: 'title_empty' },
    });
  });

  it('rechaza un título de solo espacios', () => {
    expect(createTask({ title: ' \t\n ' }, context)).toEqual({
      ok: false,
      error: { kind: 'title_empty' },
    });
  });

  it('acepta un título de exactamente el largo máximo', () => {
    const title = 'a'.repeat(TASK_TITLE_MAX_LENGTH);
    expect(createTask({ title }, context)).toEqual({
      ok: true,
      value: { id: context.id, title, createdAt: context.now },
    });
  });

  it('rechaza un título un carácter más largo que el máximo, e informa el máximo', () => {
    const title = 'a'.repeat(TASK_TITLE_MAX_LENGTH + 1);
    expect(createTask({ title }, context)).toEqual({
      ok: false,
      error: { kind: 'title_too_long', max: 120 },
    });
  });

  it('mide el largo después de recortar, no antes', () => {
    const title = `  ${'a'.repeat(TASK_TITLE_MAX_LENGTH)}  `;
    expect(createTask({ title }, context).ok).toBe(true);
  });

  it('rechaza caracteres de control en medio del título', () => {
    expect(createTask({ title: 'antes\u0000después' }, context)).toEqual({
      ok: false,
      error: { kind: 'title_has_control_characters' },
    });
    expect(createTask({ title: 'antes\tdespués' }, context)).toEqual({
      ok: false,
      error: { kind: 'title_has_control_characters' },
    });
  });

  it('acepta texto Unicode que no es de control', () => {
    expect(createTask({ title: 'Reunión ☕ 日本語' }, context).ok).toBe(true);
  });
});
