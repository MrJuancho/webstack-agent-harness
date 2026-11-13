import { describe, it, expect, beforeAll } from 'vitest';
import { FastifyInstance, RouteOptions } from 'fastify';
import { SignJWT } from 'jose';
import { buildApp, requireAuth } from '../../src/http/app.js';

// Firma un token HS256 con el secreto dado, igual que lo haría un emisor
// real. `secret` distinto del JWT_SECRET de la app = token falsificado.
function signToken(secret: string, expiresAt: string | number = '5m'): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject('auth-matrix')
    .setIssuedAt()
    .setExpirationTime(expiresAt)
    .sign(new TextEncoder().encode(secret));
}

describe('Gate 4: Matriz de Autenticación Fail-Closed', () => {
  let app: FastifyInstance;
  const registeredRoutes: RouteOptions[] = [];

  beforeAll(async () => {
    app = await buildApp({
      onRoute: (routeOptions) => {
        registeredRoutes.push(routeOptions);
      },
    });
    await app.ready();
  });

  it('toda ruta registrada debe tener requireAuth o config.isPublic = true', () => {
    const unprotectedRoutes: string[] = [];

    for (const route of registeredRoutes) {
      // Ignorar documentación y assets de Swagger
      if (route.url.startsWith('/docs')) {
        continue;
      }

      const isPublic = route.config?.isPublic === true;

      const hooks = Array.isArray(route.preHandler)
        ? route.preHandler
        : route.preHandler
          ? [route.preHandler]
          : [];

      const hasAuthHook = hooks.includes(requireAuth);

      if (!isPublic && !hasAuthHook) {
        const methods = Array.isArray(route.method) ? route.method.join('/') : route.method;
        unprotectedRoutes.push(`${methods} ${route.url}`);
      }
    }

    expect(
      unprotectedRoutes,
      `Rutas expuestas sin autenticación ni marca isPublic: ${unprotectedRoutes.join(', ')}`
    ).toEqual([]);
  });

  it('los endpoints protegidos rechazan solicitudes sin token con 401 Unauthorized', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/api/v1/profile',
    });

    expect(response.statusCode).toBe(401);
  });

  // La matriz de arriba prueba que cada ruta DECLARA requireAuth; esto
  // prueba que requireAuth, con el cableado real de buildApp() (sin
  // dobles), de verdad distingue un token válido de uno que no lo es.
  // Sin estos casos, un requireAuth que acepte cualquier "Bearer x" pasa
  // el gate entero.
  describe('la protección es real, no solo declarada', () => {
    const profile = (token: string) =>
      app.inject({
        method: 'GET',
        url: '/api/v1/profile',
        headers: { authorization: `Bearer ${token}` },
      });

    it('acepta un token vigente firmado con el JWT_SECRET de la app', async () => {
      const response = await profile(await signToken(process.env.JWT_SECRET ?? ''));

      expect(response.statusCode).toBe(200);
    });

    it('rechaza con 401 un Bearer que no es un JWT', async () => {
      const response = await profile('test-token');

      expect(response.statusCode).toBe(401);
    });

    it('rechaza con 401 un JWT bien formado pero firmado con otro secreto', async () => {
      const response = await profile(await signToken('forged-secret-of-at-least-32-chars!!'));

      expect(response.statusCode).toBe(401);
    });

    it('rechaza con 401 un JWT vencido, aunque la firma sea válida', async () => {
      const oneHourAgo = Math.floor(Date.now() / 1000) - 3600;
      const response = await profile(await signToken(process.env.JWT_SECRET ?? '', oneHourAgo));

      expect(response.statusCode).toBe(401);
    });
  });
});
