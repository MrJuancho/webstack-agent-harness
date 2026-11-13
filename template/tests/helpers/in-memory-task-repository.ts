import type { TaskRepository } from '../../src/application/tasks/ports.js';
import type { Task } from '../../src/domain/tasks/task.js';

// Doble en memoria del puerto TaskRepository: deja probar casos de uso y
// rutas sin Postgres. Mismo contrato que el adaptador real (más recientes
// primero, `id` como desempate) -- tests/integration/task-repository.test.ts
// prueba ese contrato contra la base de verdad.
export interface InMemoryTaskRepository extends TaskRepository {
  readonly stored: Task[];
}

export function makeInMemoryTaskRepository(): InMemoryTaskRepository {
  const stored: Task[] = [];

  return {
    stored,
    insert(task) {
      stored.push(task);
      return Promise.resolve();
    },
    listRecent(limit) {
      const sorted = [...stored].sort(
        (a, b) => b.createdAt.getTime() - a.createdAt.getTime() || b.id.localeCompare(a.id)
      );
      return Promise.resolve(sorted.slice(0, limit));
    },
  };
}
