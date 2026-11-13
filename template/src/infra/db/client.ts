import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { loadEnvFiles, readDatabaseConfig } from '../config.js';
import * as schema from './schema.js';

// La URL sale validada de src/infra/config.ts (DATABASE_URL, o el
// Postgres de ESTE worktree vía PG_PORT fuera de producción).
loadEnvFiles();
const connectionString = readDatabaseConfig(process.env).url;

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
