import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.js';

const connectionString =
  process.env.DATABASE_URL ?? 'postgres://postgres:postgres@127.0.0.1:5432/webstack_dev';

type QueryListener = (query: string) => void;
let activeQueryListener: QueryListener | null = null;

export function setQueryListener(listener: QueryListener | null): void {
  activeQueryListener = listener;
}

export const sqlClient = postgres(connectionString, {
  max: 10,
  idle_timeout: 20,
  connect_timeout: 10,
  debug: (_connection, query) => {
    if (activeQueryListener) {
      activeQueryListener(query);
    }
  },
});

export const db = drizzle(sqlClient, { schema });
