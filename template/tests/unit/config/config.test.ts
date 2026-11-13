import { describe, it, expect } from 'vitest';
import { ConfigError, readDatabaseConfig, readServerConfig } from '../../../src/infra/config.js';

const SECRET = 'unit-test-secret-of-at-least-32-chars';

function problemsOf(read: () => unknown): readonly string[] {
  try {
    read();
  } catch (error) {
    if (error instanceof ConfigError) {
      return error.problems;
    }
    throw error;
  }
  throw new Error('se esperaba ConfigError y no lanzó');
}

describe('readServerConfig', () => {
  it('con solo JWT_SECRET usa los defaults de desarrollo', () => {
    const config = readServerConfig({ JWT_SECRET: SECRET, PG_PORT: '25000' });

    expect(config).toMatchObject({
      nodeEnv: 'development',
      host: '0.0.0.0',
      port: 3000,
      logLevel: 'info',
      jwtSecret: SECRET,
    });
    expect(config.database.url).toMatch(/^postgres:\/\/postgres:postgres@127\.0\.0\.1:25000\//);
  });

  it('respeta los valores explícitos', () => {
    const config = readServerConfig({
      NODE_ENV: 'production',
      HOST: '127.0.0.1',
      PORT: '8080',
      LOG_LEVEL: 'warn',
      JWT_SECRET: SECRET,
      DATABASE_URL: 'postgresql://app:pw@db.internal:5432/app',
    });

    expect(config).toEqual({
      nodeEnv: 'production',
      host: '127.0.0.1',
      port: 8080,
      logLevel: 'warn',
      jwtSecret: SECRET,
      database: { url: 'postgresql://app:pw@db.internal:5432/app' },
    });
  });

  it('con NODE_ENV=test no loguea por defecto, salvo LOG_LEVEL explícito', () => {
    expect(readServerConfig({ NODE_ENV: 'test', JWT_SECRET: SECRET }).logLevel).toBe('silent');
    expect(
      readServerConfig({ NODE_ENV: 'test', LOG_LEVEL: 'debug', JWT_SECRET: SECRET }).logLevel
    ).toBe('debug');
  });

  it('en producción exige DATABASE_URL: no cae al Postgres local por defecto', () => {
    const problems = problemsOf(() =>
      readServerConfig({ NODE_ENV: 'production', JWT_SECRET: SECRET })
    );

    expect(problems).toEqual(['DATABASE_URL es obligatorio con NODE_ENV=production.']);
  });

  it('rechaza un PORT que no es un puerto, en vez de convertirlo en NaN', () => {
    for (const port of ['abc', '-1', '3000.5', '70000', '']) {
      const problems = problemsOf(() => readServerConfig({ JWT_SECRET: SECRET, PORT: port }));
      expect(problems).toEqual([
        `PORT="${port}" no es un puerto válido (entero entre 0 y 65535).`,
      ]);
    }
  });

  it('rechaza JWT_SECRET ausente o corto', () => {
    expect(problemsOf(() => readServerConfig({}))[0]).toMatch(/JWT_SECRET no está definido/);
    expect(problemsOf(() => readServerConfig({ JWT_SECRET: 'short' }))).toEqual([
      'JWT_SECRET tiene 5 caracteres; el mínimo es 32.',
    ]);
  });

  it('informa TODOS los problemas juntos, no solo el primero', () => {
    const problems = problemsOf(() =>
      readServerConfig({
        NODE_ENV: 'staging',
        PORT: 'abc',
        LOG_LEVEL: 'verbose',
        DATABASE_URL: 'mysql://localhost/app',
      })
    );

    expect(problems).toHaveLength(5);
    expect(problems.join('\n')).toMatch(/NODE_ENV="staging"/);
    expect(problems.join('\n')).toMatch(/DATABASE_URL debe empezar con postgres/);
    expect(problems.join('\n')).toMatch(/PORT="abc"/);
    expect(problems.join('\n')).toMatch(/LOG_LEVEL="verbose"/);
    expect(problems.join('\n')).toMatch(/JWT_SECRET no está definido/);
  });

  it('el mensaje del error lista cada problema en su propia línea', () => {
    let message = '';
    try {
      readServerConfig({ PORT: 'abc' });
    } catch (error) {
      message = (error as Error).message;
    }

    expect(message).toMatch(/^Configuración inválida \(2 problema\(s\)\):\n {2}- PORT="abc"/);
  });
});

describe('readDatabaseConfig', () => {
  it('no exige JWT_SECRET: migrar no necesita autenticar requests', () => {
    expect(readDatabaseConfig({ PG_PORT: '25000' }).url).toMatch(/127\.0\.0\.1:25000\//);
  });

  it('usa DATABASE_URL si está definida', () => {
    const url = 'postgres://app:pw@db.internal:5432/app';

    expect(readDatabaseConfig({ DATABASE_URL: url })).toEqual({ url });
  });

  it('rechaza un PG_PORT inválido y exige DATABASE_URL en producción', () => {
    expect(problemsOf(() => readDatabaseConfig({ PG_PORT: 'abc' }))).toEqual([
      'PG_PORT="abc" no es un puerto válido (entero entre 0 y 65535).',
    ]);
    expect(problemsOf(() => readDatabaseConfig({ NODE_ENV: 'production' }))).toEqual([
      'DATABASE_URL es obligatorio con NODE_ENV=production.',
    ]);
  });
});
