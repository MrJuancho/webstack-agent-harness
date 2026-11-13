import { describe, it, expect } from 'vitest';
import { SignJWT, UnsecuredJWT } from 'jose';
import {
  JWT_SECRET_MIN_LENGTH,
  makeJwtVerifier,
  requireJwtSecret,
} from '../../../src/infra/auth/jwt-verifier.js';

const SECRET = 'unit-test-secret-of-at-least-32-chars';
const OTHER_SECRET = 'another-unit-test-secret-32-chars-xx';
const key = (secret: string) => new TextEncoder().encode(secret);

function sign(secret: string, options: { subject?: string; expiresAt?: string | number } = {}) {
  let jwt = new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setIssuedAt();
  if (options.subject !== undefined) {
    jwt = jwt.setSubject(options.subject);
  }
  if (options.expiresAt !== undefined) {
    jwt = jwt.setExpirationTime(options.expiresAt);
  }
  return jwt.sign(key(secret));
}

describe('makeJwtVerifier', () => {
  const verify = makeJwtVerifier({ secret: SECRET });

  it('acepta un token HS256 vigente firmado con el secreto, y devuelve su subject', async () => {
    const token = await sign(SECRET, { subject: 'user-1', expiresAt: '5m' });

    expect(await verify(token)).toEqual({ subject: 'user-1' });
  });

  it('rechaza texto que no es un JWT', async () => {
    expect(await verify('test-token')).toBeNull();
    expect(await verify('')).toBeNull();
  });

  it('rechaza un token firmado con otro secreto', async () => {
    const token = await sign(OTHER_SECRET, { subject: 'user-1', expiresAt: '5m' });

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token vencido', async () => {
    const oneHourAgo = Math.floor(Date.now() / 1000) - 3600;
    const token = await sign(SECRET, { subject: 'user-1', expiresAt: oneHourAgo });

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token sin vencimiento', async () => {
    const token = await sign(SECRET, { subject: 'user-1' });

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token sin subject', async () => {
    const token = await sign(SECRET, { expiresAt: '5m' });

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token sin firma (alg: none)', async () => {
    const token = new UnsecuredJWT({}).setSubject('user-1').setExpirationTime('5m').encode();

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token firmado con el secreto correcto pero otro algoritmo', async () => {
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: 'HS512' })
      .setSubject('user-1')
      .setExpirationTime('5m')
      .sign(key(SECRET));

    expect(await verify(token)).toBeNull();
  });

  it('rechaza un token con el payload alterado después de firmar', async () => {
    const token = await sign(SECRET, { subject: 'user-1', expiresAt: '5m' });
    const [header, , signature] = token.split('.');
    const forgedPayload = Buffer.from(
      JSON.stringify({ sub: 'admin', exp: Math.floor(Date.now() / 1000) + 300 })
    ).toString('base64url');

    expect(await verify(`${header}.${forgedPayload}.${signature}`)).toBeNull();
  });
});

describe('requireJwtSecret (falla cerrado)', () => {
  it('lanza si el secreto no está definido o está vacío', () => {
    expect(() => requireJwtSecret(undefined)).toThrow(/JWT_SECRET no está definido/);
    expect(() => requireJwtSecret('')).toThrow(/JWT_SECRET no está definido/);
  });

  it('lanza si el secreto es más corto que el mínimo', () => {
    const short = 'a'.repeat(JWT_SECRET_MIN_LENGTH - 1);

    expect(() => requireJwtSecret(short)).toThrow(/el mínimo es 32/);
    expect(() => makeJwtVerifier({ secret: short })).toThrow(/el mínimo es 32/);
  });

  it('acepta un secreto de exactamente el largo mínimo', () => {
    const exact = 'a'.repeat(JWT_SECRET_MIN_LENGTH);

    expect(requireJwtSecret(exact)).toBe(exact);
  });

  it('makeJwtVerifier no se puede construir sin secreto', () => {
    expect(() => makeJwtVerifier({ secret: undefined })).toThrow(/JWT_SECRET no está definido/);
  });
});
