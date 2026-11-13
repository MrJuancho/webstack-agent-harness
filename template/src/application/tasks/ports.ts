import type { Task } from '../../domain/tasks/task.js';

// Puertos: lo que los casos de uso NECESITAN del mundo exterior, declarado
// por la capa de aplicación en sus propios términos. `src/infra/` los
// implementa (ver src/infra/db/task-repository.ts); la aplicación nunca
// importa de infra -- `application-isolation` en .dependency-cruiser.js.

export interface TaskRepository {
  insert(task: Task): Promise<void>;
  // Las más recientes primero.
  listRecent(limit: number): Promise<Task[]>;
}

// El reloj y la fuente de ids entran por acá: el dominio no puede leerlos
// (Gate 10), así que el caso de uso los lee de sus dependencias y se los
// pasa al dominio como valores.
export type Clock = () => Date;
export type IdGenerator = () => string;
