import { errors, jwtVerify } from 'jose';
import type { TokenVerifier } from '../../application/auth/ports.js';

export const JWT_SECRET_MIN_LENGTH = 32;

// Falla cerrado: sin secreto, o con uno corto, no hay verificador -- y
// sin verificador `buildApp` no arranca. No existe un secreto por defecto
// "para desarrollo": un valor conocido que llega a producción por un
// NODE_ENV mal puesto es exactamente el accidente que esto evita. En
// local lo genera scripts/worktree-env.sh en .env.local.
export function requireJwtSecret(value: string | undefined): string {
  if (value === undefined || value.length === 0) {
    throw new Error(
      'JWT_SECRET no está definido: el servidor no arranca sin él. En local, correr `bash scripts/worktree-env.sh` (lo genera en .env.local); en producción, definirlo en el entorno.'
    );
  }
  if (value.length < JWT_SECRET_MIN_LENGTH) {
    throw new Error(
      `JWT_SECRET tiene ${value.length} caracteres; el mínimo es ${JWT_SECRET_MIN_LENGTH}.`
    );
  }
  return value;
}

export function encodeJwtSecret(secret: string): Uint8Array {
  return new TextEncoder().encode(secret);
}

export interface JwtVerifierOptions {
  readonly secret: string | undefined;
}

export function makeJwtVerifier(options: JwtVerifierOptions): TokenVerifier {
  const key = encodeJwtSecret(requireJwtSecret(options.secret));

  return async (token) => {
    try {
      // `algorithms` fijo: sin esto, un token con `alg: none` o con otro
      // algoritmo elegido por quien lo envía podría pasar. `exp` y `sub`
      // obligatorios: un token sin vencimiento no se acepta.
      const { payload } = await jwtVerify(token, key, {
        algorithms: ['HS256'],
        requiredClaims: ['sub', 'exp'],
      });
      if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
        return null;
      }
      return { subject: payload.sub };
    } catch (error) {
      // Solo los rechazos de la librería (firma, vencimiento, formato)
      // significan "no autenticado". Cualquier otro error es un bug y
      // sigue subiendo -- no se traga.
      if (error instanceof errors.JOSEError) {
        return null;
      }
      throw error;
    }
  };
}
