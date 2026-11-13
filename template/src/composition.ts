import { randomUUID } from 'node:crypto';
import { makeCreateTask } from './application/tasks/create-task.js';
import { makeListTasks } from './application/tasks/list-tasks.js';
import type { UseCases } from './application/use-cases.js';
import { db } from './infra/db/client.js';
import { makeTaskRepository } from './infra/db/task-repository.js';

// Raíz de composición: el ÚNICO archivo que conoce todas las capas a la
// vez y conecta cada puerto con su adaptador real. También es el único
// lugar donde se lee el reloj y se generan ids de verdad -- de acá para
// adentro son dependencias inyectadas.
export function buildUseCases(): UseCases {
  const tasks = makeTaskRepository(db);

  return {
    createTask: makeCreateTask({ tasks, clock: () => new Date(), newId: randomUUID }),
    listTasks: makeListTasks({ tasks }),
  };
}
