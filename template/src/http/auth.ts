import type { FastifyReply, FastifyRequest } from 'fastify';

// Hook de autenticación centinela
export const requireAuth = async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    await reply.status(401).send({ error: 'Unauthorized: Missing or invalid token' });
    return;
  }
};
