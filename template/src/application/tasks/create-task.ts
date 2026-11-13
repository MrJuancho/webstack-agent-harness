import { createTask, type Result, type Task, type TaskError } from '../../domain/tasks/task.js';
import type { Clock, IdGenerator, TaskRepository } from './ports.js';

export interface CreateTaskDeps {
  readonly tasks: TaskRepository;
  readonly clock: Clock;
  readonly newId: IdGenerator;
}

export type CreateTask = (input: { title: string }) => Promise<Result<Task, TaskError>>;

// Un caso de uso ORQUESTA, no decide: lee el reloj y el id de sus
// dependencias, le pide la decisión al dominio, y persiste solo si el
// dominio aceptó. Si acá aparece un `if` sobre los datos de la tarea, esa
// regla pertenece a src/domain/ (donde Stryker sí la muta).
export function makeCreateTask(deps: CreateTaskDeps): CreateTask {
  return async (input) => {
    const result = createTask(input, { id: deps.newId(), now: deps.clock() });
    if (!result.ok) {
      return result;
    }
    await deps.tasks.insert(result.value);
    return result;
  };
}
