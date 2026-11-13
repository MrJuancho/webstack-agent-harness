import { describe, it, expect, afterAll } from 'vitest';
import { inArray } from 'drizzle-orm';
import { db } from '../../src/infra/db/client.js';
import { tasks } from '../../src/infra/db/schema.js';
import { makeTaskRepository } from '../../src/infra/db/task-repository.js';
import { assertMaxQueries } from '../helpers/query-counter.js';

// El adaptador real contra Postgres: prueba el contrato del puerto
// TaskRepository (el mismo que imita el doble en memoria) y el Gate 6.
describe('TaskRepository sobre Postgres', () => {
  const repository = makeTaskRepository(db);

  // Instantes en un futuro lejano: quedan primeros en `listRecent` aunque
  // la base de desarrollo ya tenga otras tareas (seed, corridas de
  // contratos), sin tener que vaciar la tabla.
  const fixtures = [
    {
      id: 'c0000000-0000-0000-0000-000000000001',
      title: 'primera',
      createdAt: new Date('2999-01-01T00:00:00.000Z'),
    },
    {
      id: 'c0000000-0000-0000-0000-000000000002',
      title: 'segunda',
      createdAt: new Date('2999-01-02T00:00:00.000Z'),
    },
    {
      id: 'c0000000-0000-0000-0000-000000000003',
      title: 'mismo instante que la segunda',
      createdAt: new Date('2999-01-02T00:00:00.000Z'),
    },
  ];
  const fixtureIds = fixtures.map((task) => task.id);

  afterAll(async () => {
    await db.delete(tasks).where(inArray(tasks.id, fixtureIds));
  });

  it('insert + listRecent: más recientes primero, id como desempate, en 1 consulta', async () => {
    await db.delete(tasks).where(inArray(tasks.id, fixtureIds));
    for (const task of fixtures) {
      await repository.insert(task);
    }

    const listed = await assertMaxQueries(1, () => repository.listRecent(3));

    expect(listed).toEqual([fixtures[2], fixtures[1], fixtures[0]]);
  });

  it('listRecent respeta el límite', async () => {
    const listed = await repository.listRecent(1);

    expect(listed).toEqual([fixtures[2]]);
  });
});
