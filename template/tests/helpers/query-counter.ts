import { setQueryListener } from '../../src/infra/db/client.js';

export interface QueryAuditResult<T> {
  result: T;
  count: number;
  queries: string[];
}

export async function countQueries<T>(operation: () => Promise<T>): Promise<QueryAuditResult<T>> {
  const queries: string[] = [];
  setQueryListener((query) => {
    // Filtrar transacciones automáticas internas de inicio/cierre si se desea
    queries.push(query.trim());
  });

  try {
    const result = await operation();
    return { result, count: queries.length, queries };
  } finally {
    setQueryListener(null);
  }
}

export async function assertMaxQueries<T>(
  maxAllowed: number,
  operation: () => Promise<T>
): Promise<T> {
  const { result, count, queries } = await countQueries(operation);

  if (count > maxAllowed) {
    const formattedQueries = queries.map((q, idx) => `  [${idx + 1}] ${q}`).join('\n');
    throw new Error(
      `Gate 6 Violated: Se esperaban <= ${maxAllowed} consultas SQL, pero se ejecutaron ${count}:\n${formattedQueries}`
    );
  }

  return result;
}
