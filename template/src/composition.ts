import { randomUUID } from 'node:crypto';
import type { TokenVerifier } from './application/auth/ports.js';
import { makeCreateTask } from './application/tasks/create-task.js';
import { makeListTasks } from './application/tasks/list-tasks.js';
import type { UseCases } from './application/use-cases.js';
import { makeJwtVerifier } from './infra/auth/jwt-verifier.js';
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

// Lee JWT_SECRET del entorno (ya cargado: importar ./infra/db/client.js
// arriba corre dotenv sobre .env y .env.local). Lanza si falta o es corto
// -- `buildApp` lo llama al construir la app, así que el servidor no
// llega a escuchar sin un secreto válido.
export function buildTokenVerifier(): TokenVerifier {
  return makeJwtVerifier({ secret: process.env.JWT_SECRET });
}
