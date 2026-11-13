import { describe, it, expect, beforeEach } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../../../src/http/app.js';
import { makeCreateTask } from '../../../src/application/tasks/create-task.js';
import { makeListTasks } from '../../../src/application/tasks/list-tasks.js';
import {
  makeInMemoryTaskRepository,
  type InMemoryTaskRepository,
} from '../../helpers/in-memory-task-repository.js';

// Las rutas se prueban con casos de uso reales sobre un repositorio en
// memoria: sin Postgres, así que corre en `just gauntlet-fast`.
const NOW = new Date('2026-01-01T00:00:00.000Z');
const ID = 'b0000000-0000-0000-0000-000000000001';
const AUTH = { authorization: 'Bearer test-token' };

describe('rutas de tareas (/api/v1/tasks)', () => {
  let app: FastifyInstance;
  let tasks: InMemoryTaskRepository;

  beforeEach(async () => {
    tasks = makeInMemoryTaskRepository();
    app = await buildApp({
      // Verificador de prueba: acepta solo este token. El real (JWT) tiene
      // sus propios tests en tests/unit/auth/ y tests/architecture/.
      verifyToken: (token) => Promise.resolve(token === 'test-token' ? { subject: 'user-1' } : null),
      useCases: {
        createTask: makeCreateTask({ tasks, clock: () => NOW, newId: () => ID }),
        listTasks: makeListTasks({ tasks }),
      },
    });
    await app.ready();
  });

  it('POST crea la tarea y responde 201 con el recurso', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/tasks',
      headers: AUTH,
      payload: { title: '  Escribir el ADR  ' },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toEqual({
      id: ID,
      title: 'Escribir el ADR',
      createdAt: '2026-01-01T00:00:00.000Z',
    });
    expect(tasks.stored).toHaveLength(1);
  });

  it('POST responde 422 con el mensaje del error de dominio, y no persiste', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/tasks',
      headers: AUTH,
      payload: { title: '   ' },
    });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toEqual({ error: 'Title must not be empty' });
    expect(tasks.stored).toEqual([]);
  });

  it('POST responde 400 con forma ErrorResponse si el cuerpo no cumple el esquema', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/tasks',
      headers: AUTH,
      payload: {},
    });

    expect(response.statusCode).toBe(400);
    expect(Object.keys(response.json())).toEqual(['error']);
  });

  it('POST y GET responden 401 con un token que el verificador rechaza', async () => {
    const headers = { authorization: 'Bearer otro-token' };
    const post = await app.inject({
      method: 'POST',
      url: '/api/v1/tasks',
      headers,
      payload: { title: 'x' },
    });
    const get = await app.inject({ method: 'GET', url: '/api/v1/tasks', headers });

    expect(post.statusCode).toBe(401);
    expect(get.statusCode).toBe(401);
    expect(tasks.stored).toEqual([]);
  });

  it('POST y GET responden 401 sin token', async () => {
    const post = await app.inject({
      method: 'POST',
      url: '/api/v1/tasks',
      payload: { title: 'x' },
    });
    const get = await app.inject({ method: 'GET', url: '/api/v1/tasks' });

    expect(post.statusCode).toBe(401);
    expect(get.statusCode).toBe(401);
    expect(tasks.stored).toEqual([]);
  });

  it('GET lista las tareas y respeta ?limit', async () => {
    await tasks.insert({ id: ID, title: 'vieja', createdAt: NOW });
    await tasks.insert({
      id: 'b0000000-0000-0000-0000-000000000002',
      title: 'nueva',
      createdAt: new Date('2026-01-02T00:00:00.000Z'),
    });

    const all = await app.inject({ method: 'GET', url: '/api/v1/tasks', headers: AUTH });
    const one = await app.inject({ method: 'GET', url: '/api/v1/tasks?limit=1', headers: AUTH });

    expect(all.statusCode).toBe(200);
    expect(all.json().items.map((item: { title: string }) => item.title)).toEqual([
      'nueva',
      'vieja',
    ]);
    expect(one.json().items).toHaveLength(1);
  });

  it('GET responde 400 si ?limit está fuera de rango', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/tasks?limit=0',
      headers: AUTH,
    });

    expect(response.statusCode).toBe(400);
    expect(Object.keys(response.json())).toEqual(['error']);
  });
});
