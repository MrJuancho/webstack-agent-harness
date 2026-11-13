import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';
import { loadEnvFiles, readDatabaseConfig } from '../config.js';

// La URL sale validada de src/infra/config.ts (DATABASE_URL, o el
// Postgres de ESTE worktree vía PG_PORT fuera de producción).
loadEnvFiles();
const connectionString = readDatabaseConfig(process.env).url;

const sql = postgres(connectionString, { max: 1 });
const db = drizzle(sql);

export async function runMigrations(): Promise<void> {
  await migrate(db, { migrationsFolder: 'src/infra/db/migrations' });
  await sql.end();
}

await runMigrations();
