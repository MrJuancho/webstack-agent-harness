import type { Task } from '../../domain/tasks/task.js';
import type { TaskRepository } from './ports.js';

export interface ListTasksDeps {
  readonly tasks: TaskRepository;
}

export type ListTasks = (input: { limit: number }) => Promise<Task[]>;

export function makeListTasks(deps: ListTasksDeps): ListTasks {
  return (input) => deps.tasks.listRecent(input.limit);
}
