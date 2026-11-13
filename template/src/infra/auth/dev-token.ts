import { SignJWT } from 'jose';
import { loadEnvFiles } from '../config.js';
import { encodeJwtSecret, requireJwtSecret } from './jwt-verifier.js';

// Emite un token de corta duración firmado con el JWT_SECRET de este
// worktree: `just dev-token [subject]`. Para probar a mano con curl, y
// para el gate de contratos (scripts/test-contracts.sh). NO es un flujo
// de login -- emitir tokens de verdad le toca al proveedor de identidad
// del proyecto.

loadEnvFiles();

if (process.env.NODE_ENV === 'production') {
  console.error('dev-token: deshabilitado con NODE_ENV=production.');
  process.exit(1);
}

const subject = process.argv[2] ?? 'dev-user';
const token = await new SignJWT({})
  .setProtectedHeader({ alg: 'HS256' })
  .setSubject(subject)
  .setIssuedAt()
  .setExpirationTime('1h')
  .sign(encodeJwtSecret(requireJwtSecret(process.env.JWT_SECRET)));

console.log(token);
