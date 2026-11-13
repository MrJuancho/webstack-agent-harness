// Feature de referencia: el patrón a copiar para lógica de negocio nueva.
// Todo lo que DECIDE algo sobre una tarea vive acá -- puro, sin I/O, sin
// reloj, sin aleatoriedad (Gate 10): el `id` y el instante `now` llegan
// como parámetros desde la capa de aplicación. Ver AGENTS.md,
// "Convención de capas".

export const TASK_TITLE_MAX_LENGTH = 120;

export interface Task {
  readonly id: string;
  readonly title: string;
  readonly createdAt: Date;
}

export type TaskError =
  | { readonly kind: 'title_empty' }
  | { readonly kind: 'title_too_long'; readonly max: number }
  | { readonly kind: 'title_has_control_characters' };

// Los errores de negocio esperados son valores, no excepciones: el
// llamador está obligado por el tipo a manejarlos, y la capa HTTP los
// traduce a un status sin try/catch.
export type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

export interface NewTaskInput {
  readonly title: string;
}

export interface NewTaskContext {
  readonly id: string;
  readonly now: Date;
}

// Caracteres de control Unicode (categoría Cc): incluye NUL, que Postgres
// rechaza en una columna `text` -- sin esta regla, un título con "\u0000"
// llegaría hasta la base y volvería como un 500.
const CONTROL_CHARACTER = /\p{Cc}/u;

export function createTask(input: NewTaskInput, context: NewTaskContext): Result<Task, TaskError> {
  const title = input.title.trim();

  if (title.length === 0) {
    return { ok: false, error: { kind: 'title_empty' } };
  }
  if (title.length > TASK_TITLE_MAX_LENGTH) {
    return { ok: false, error: { kind: 'title_too_long', max: TASK_TITLE_MAX_LENGTH } };
  }
  if (CONTROL_CHARACTER.test(title)) {
    return { ok: false, error: { kind: 'title_has_control_characters' } };
  }

  return { ok: true, value: { id: context.id, title, createdAt: context.now } };
}
