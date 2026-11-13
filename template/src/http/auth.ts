import type { FastifyReply, FastifyRequest } from 'fastify';
import type { Principal, TokenVerifier } from '../application/auth/ports.js';

declare module 'fastify' {
  interface FastifyInstance {
    // Lo decora buildApp (src/http/app.ts) con el verificador real o con
    // el que le pasen los tests.
    verifyToken: TokenVerifier;
  }
  interface FastifyRequest {
    // Quién hace el request; `null` hasta que requireAuth lo verifica.
    principal: Principal | null;
  }
}

const BEARER_PREFIX = 'Bearer ';

// Hook de autenticación: el token tiene que estar Y ser válido según
// `verifyToken` -- la presencia del header sola no alcanza.
export const requireAuth = async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
  const authHeader = request.headers.authorization;
  const token = authHeader?.startsWith(BEARER_PREFIX)
    ? authHeader.slice(BEARER_PREFIX.length)
    : undefined;
  const principal = token ? await request.server.verifyToken(token) : null;

  if (!principal) {
    await reply.status(401).send({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }
  request.principal = principal;
};
