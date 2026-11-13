import { index, pgTable, uuid, text, timestamp } from 'drizzle-orm/pg-core';

export const auditLogs = pgTable('audit_logs', {
  id: uuid('id').defaultRandom().primaryKey(),
  action: text('action').notNull(),
  entity: text('entity').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
});

// Sin defaults a propósito: el `id` y `created_at` los decide la
// aplicación (reloj e ids inyectados, ver src/composition.ts), no la base
// -- así el dominio se puede probar con valores fijos y los seeds son
// deterministas (Gate 7).
export const tasks = pgTable(
  'tasks',
  {
    id: uuid('id').primaryKey(),
    title: text('title').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
  },
  (table) => [index('tasks_created_at_id_idx').on(table.createdAt, table.id)]
);
