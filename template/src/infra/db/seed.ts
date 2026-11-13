import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { loadEnvFiles, readDatabaseConfig } from '../config.js';
import { auditLogs, tasks } from './schema.js';

// La URL sale validada de src/infra/config.ts (DATABASE_URL, o el
// Postgres de ESTE worktree vía PG_PORT fuera de producción).
loadEnvFiles();
const connectionString = readDatabaseConfig(process.env).url;

const sql = postgres(connectionString, { max: 1 });
const db = drizzle(sql);

export async function seed(): Promise<void> {
  // Los seeds deterministas NUNCA usan Date.now() ni UUIDs aleatorios
  await db.insert(auditLogs).values([
    {
      id: 'a0000000-0000-0000-0000-000000000001',
      action: 'SYSTEM_INIT',
      entity: 'SYSTEM',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      id: 'a0000000-0000-0000-0000-000000000002',
      action: 'DEFAULT_ROLE_CREATED',
      entity: 'ROLE',
      createdAt: new Date('2026-01-01T00:00:01.000Z'),
    },
  ]);

  await db.insert(tasks).values([
    {
      id: 'b0000000-0000-0000-0000-000000000001',
      title: 'Leer AGENTS.md',
      createdAt: new Date('2026-01-01T00:00:02.000Z'),
    },
    {
      id: 'b0000000-0000-0000-0000-000000000002',
      title: 'Reemplazar la feature de referencia por la primera real',
      createdAt: new Date('2026-01-01T00:00:03.000Z'),
    },
  ]);

  await sql.end();
}

await seed();
