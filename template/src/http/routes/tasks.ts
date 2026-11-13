import type { FastifyPluginCallbackTypebox } from '@fastify/type-provider-typebox';
import { Type, type Static } from '@sinclair/typebox';
import type { UseCases } from '../../application/use-cases.js';
import type { Task, TaskError } from '../../domain/tasks/task.js';
import { requireAuth } from '../auth.js';
import { ErrorResponse } from '../errors.js';

// Feature de referencia, capa HTTP: el patrón a copiar para rutas nuevas.
// Un handler solo TRADUCE -- request a entrada del caso de uso, resultado
// a status + cuerpo. Los esquemas validan la FORMA (hay un `title` y es
// string); las reglas de negocio (qué título es válido) las decide el
// dominio y acá solo se mapean a un 422.

const DEFAULT_LIST_LIMIT = 20;
const MAX_LIST_LIMIT = 100;

const TaskResponse = Type.Object(
  {
    id: Type.String({ format: 'uuid' }),
    title: Type.String(),
    createdAt: Type.String({ format: 'date-time' }),
  },
  { additionalProperties: false }
);

const CreateTaskBody = Type.Object({ title: Type.String() }, { additionalProperties: false });

const ListTasksQuery = Type.Object(
  {
    limit: Type.Optional(
      Type.Integer({ minimum: 1, maximum: MAX_LIST_LIMIT, default: DEFAULT_LIST_LIMIT })
    ),
  },
  { additionalProperties: false }
);

const ListTasksResponse = Type.Object(
  { items: Type.Array(TaskResponse) },
  { additionalProperties: false }
);

function toTaskResponse(task: Task): Static<typeof TaskResponse> {
  return { id: task.id, title: task.title, createdAt: task.createdAt.toISOString() };
}

// El `switch` sin `default` es a propósito: si el dominio suma un
// TaskError nuevo, esto deja de compilar hasta que se le escriba mensaje.
function describeTaskError(error: TaskError): string {
  switch (error.kind) {
    case 'title_empty':
      return 'Title must not be empty';
    case 'title_too_long':
      return `Title must be at most ${error.max} characters`;
    case 'title_has_control_characters':
      return 'Title must not contain control characters';
  }
}

export interface TaskRoutesOptions {
  readonly useCases: UseCases;
}

export const taskRoutes: FastifyPluginCallbackTypebox<TaskRoutesOptions> = (app, options, done) => {
  const { useCases } = options;

  app.post(
    '/api/v1/tasks',
    {
      preHandler: [requireAuth],
      schema: {
        description: 'Crea una tarea',
        security: [{ bearerAuth: [] }],
        body: CreateTaskBody,
        response: {
          201: TaskResponse,
          400: ErrorResponse,
          401: ErrorResponse,
          422: ErrorResponse,
        },
      },
    },
    async (request, reply) => {
      const result = await useCases.createTask({ title: request.body.title });
      if (!result.ok) {
        return reply.status(422).send({ error: describeTaskError(result.error) });
      }
      return reply.status(201).send(toTaskResponse(result.value));
    }
  );

  app.get(
    '/api/v1/tasks',
    {
      preHandler: [requireAuth],
      schema: {
        description: 'Lista las tareas más recientes primero',
        security: [{ bearerAuth: [] }],
        querystring: ListTasksQuery,
        response: {
          200: ListTasksResponse,
          400: ErrorResponse,
          401: ErrorResponse,
        },
      },
    },
    async (request) => {
      const tasks = await useCases.listTasks({ limit: request.query.limit ?? DEFAULT_LIST_LIMIT });
      return { items: tasks.map(toTaskResponse) };
    }
  );

  done();
};
