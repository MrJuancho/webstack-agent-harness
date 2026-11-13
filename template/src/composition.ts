import { randomUUID } from 'node:crypto';
import type { TokenVerifier } from './application/auth/ports.js';
import { makeCreateTask } from './application/tasks/create-task.js';
import { makeListTasks } from './application/tasks/list-tasks.js';
import type { UseCases } from './application/use-cases.js';
import { makeJwtVerifier } from './infra/auth/jwt-verifier.js';
import { db, sqlClient } from './infra/db/client.js';
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
// arriba corre dotenv sobre .env y .env.local). Lanza si falta o es corto.
// Con el servidor real, src/main.ts ya lo validó antes de llegar acá;
// esto cubre a quien construye la app sin pasar por main (los tests).
export function buildTokenVerifier(): TokenVerifier {
  return makeJwtVerifier({ secret: process.env.JWT_SECRET });
}

// Libera lo que la raíz de composición abrió (el pool de Postgres). Parte
// del apagado ordenado: se llama después de `app.close()`, cuando ya no
// quedan requests en curso que lo necesiten.
export async function closeResources(): Promise<void> {
  await sqlClient.end({ timeout: 5 });
}
