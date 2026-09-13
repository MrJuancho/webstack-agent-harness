import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { db, sqlClient } from '../../src/infra/db/client.js';
import { auditLogs } from '../../src/infra/db/schema.js';
import { assertMaxQueries } from '../helpers/query-counter.js';
import { inArray, eq } from 'drizzle-orm';

describe('Gate 6: Detección de Consultas N+1 e Integración con DB', () => {
  const createdIds: string[] = [];

  beforeAll(async () => {
    // 1. Asegurar que la tabla exista aplicando las migraciones pendientes
    await sqlClient`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `;

    // 2. Sembrar registros de prueba en lote (1 sola consulta)
    const inserted = await db
      .insert(auditLogs)
      .values([
        { action: 'CREATE', entity: 'USER' },
        { action: 'UPDATE', entity: 'USER' },
        { action: 'DELETE', entity: 'SESSION' },
        { action: 'LOGIN', entity: 'AUTH' },
      ])
      .returning({ id: auditLogs.id });

    createdIds.push(...inserted.map((row) => row.id));
  });

  afterAll(async () => {
    // Limpieza de datos insertados
    if (createdIds.length > 0) {
      await db.delete(auditLogs).where(inArray(auditLogs.id, createdIds));
    }
  });

  it('consulta por lotes (Batch Query) ejecuta exactamente 1 consulta SQL', async () => {
    await assertMaxQueries(1, async () => {
      const results = await db
        .select()
        .from(auditLogs)
        .where(inArray(auditLogs.id, createdIds));
      expect(results.length).toBe(createdIds.length);
    });
  });

  it('detecta y bloquea un patrón N+1 que realiza consultas individuales dentro de un bucle', async () => {
    // Simulación del error de un agente: iterar y consultar elemento por elemento
    const executeNPlusOne = async () => {
      await assertMaxQueries(1, async () => {
        const items = [];
        for (const id of createdIds) {
          const item = await db.select().from(auditLogs).where(eq(auditLogs.id, id));
          items.push(item);
        }
        return items;
      });
    };

    // Falla cerrado: debe lanzar error de Gate 6 señalando las múltiples consultas
    await expect(executeNPlusOne()).rejects.toThrowError(
      /Gate 6 Violated: Se esperaban <= 1 consultas SQL, pero se ejecutaron 4/
    );
  });
});
