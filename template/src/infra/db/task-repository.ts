import { desc } from 'drizzle-orm';
import type { TaskRepository } from '../../application/tasks/ports.js';
import type { db } from './client.js';
import { tasks } from './schema.js';

// Adaptador: implementa el puerto que declara la capa de aplicación.
// Solo traduce entre el dominio y SQL -- ninguna regla de negocio acá.
export function makeTaskRepository(database: typeof db): TaskRepository {
  return {
    async insert(task) {
      await database
        .insert(tasks)
        .values({ id: task.id, title: task.title, createdAt: task.createdAt });
    },

    async listRecent(limit) {
      // Una sola consulta para toda la página (Gate 6). El `id` desempata
      // tareas con el mismo instante para que el orden sea estable.
      return database
        .select()
        .from(tasks)
        .orderBy(desc(tasks.createdAt), desc(tasks.id))
        .limit(limit);
    },
  };
}
