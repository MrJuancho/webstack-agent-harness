import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { auditLogs } from './schema.js';
import 'dotenv/config';

const connectionString =
  process.env.DATABASE_URL ?? 'postgres://postgres:postgres@127.0.0.1:5432/webstack_dev';

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

  await sql.end();
}

await seed();
