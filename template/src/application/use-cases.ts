import type { CreateTask } from './tasks/create-task.js';
import type { ListTasks } from './tasks/list-tasks.js';

// Todo lo que la capa HTTP puede pedirle a la aplicación. `buildApp`
// recibe esto ya construido: en producción lo arma src/composition.ts con
// adaptadores reales; en tests se le pasa una versión con dobles en
// memoria, sin Postgres.
export interface UseCases {
  readonly createTask: CreateTask;
  readonly listTasks: ListTasks;
}
