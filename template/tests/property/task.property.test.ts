import { describe, it } from 'vitest';
import fc from 'fast-check';
import { createTask, TASK_TITLE_MAX_LENGTH } from '../../src/domain/tasks/task.js';

const context = {
  id: 'b0000000-0000-0000-0000-000000000001',
  now: new Date('2026-01-01T00:00:00.000Z'),
};

describe('createTask (invariantes de propiedad)', () => {
  it('toda tarea aceptada tiene un título recortado, no vacío, dentro del máximo y sin caracteres de control', () => {
    fc.assert(
      fc.property(fc.string({ unit: 'binary', maxLength: 200 }), (rawTitle) => {
        const result = createTask({ title: rawTitle }, context);
        if (!result.ok) {
          return true;
        }
        const { title } = result.value;
        return (
          title === title.trim() &&
          title.length > 0 &&
          title.length <= TASK_TITLE_MAX_LENGTH &&
          !/\p{Cc}/u.test(title)
        );
      }),
      { numRuns: 1000 }
    );
  });

  it('nunca lanza: todo título, válido o no, vuelve como Result', () => {
    fc.assert(
      fc.property(fc.string({ unit: 'binary', maxLength: 200 }), (rawTitle) => {
        const result = createTask({ title: rawTitle }, context);
        return result.ok ? result.value.id === context.id : typeof result.error.kind === 'string';
      }),
      { numRuns: 1000 }
    );
  });
});
