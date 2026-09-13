import { describe, it, expect, beforeAll } from 'vitest';
import { FastifyInstance, RouteOptions } from 'fastify';
import { buildApp, requireAuth } from '../../src/http/app.js';

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
});
