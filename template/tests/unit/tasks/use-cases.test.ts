import { describe, it, expect } from 'vitest';
import { makeCreateTask } from '../../../src/application/tasks/create-task.js';
import { makeListTasks } from '../../../src/application/tasks/list-tasks.js';
import { makeInMemoryTaskRepository } from '../../helpers/in-memory-task-repository.js';

const NOW = new Date('2026-01-01T00:00:00.000Z');
const ID = 'b0000000-0000-0000-0000-000000000001';

describe('createTask (caso de uso)', () => {
  it('persiste la tarea con el id y el instante de sus dependencias', async () => {
    const tasks = makeInMemoryTaskRepository();
    const createTask = makeCreateTask({ tasks, clock: () => NOW, newId: () => ID });

    const result = await createTask({ title: '  Escribir el ADR  ' });

    const expected = { id: ID, title: 'Escribir el ADR', createdAt: NOW };
    expect(result).toEqual({ ok: true, value: expected });
    expect(tasks.stored).toEqual([expected]);
  });

  it('no persiste nada si el dominio rechaza la tarea', async () => {
    const tasks = makeInMemoryTaskRepository();
    const createTask = makeCreateTask({ tasks, clock: () => NOW, newId: () => ID });

    const result = await createTask({ title: '   ' });

    expect(result).toEqual({ ok: false, error: { kind: 'title_empty' } });
    expect(tasks.stored).toEqual([]);
  });
});

describe('listTasks (caso de uso)', () => {
  it('devuelve las más recientes primero y respeta el límite', async () => {
    const tasks = makeInMemoryTaskRepository();
    const older = { id: ID, title: 'vieja', createdAt: NOW };
    const newer = {
      id: 'b0000000-0000-0000-0000-000000000002',
      title: 'nueva',
      createdAt: new Date('2026-01-02T00:00:00.000Z'),
    };
    await tasks.insert(older);
    await tasks.insert(newer);
    const listTasks = makeListTasks({ tasks });

    expect(await listTasks({ limit: 10 })).toEqual([newer, older]);
    expect(await listTasks({ limit: 1 })).toEqual([newer]);
  });
});
