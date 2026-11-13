// Quién hace el request, ya verificado. Solo lo que la aplicación
// necesita saber -- no el token ni sus claims crudos.
export interface Principal {
  readonly subject: string;
}

// Puerto de autenticación: devuelve el Principal si el token es válido,
// `null` si no lo es (firma inválida, vencido, mal formado). Lo
// implementa src/infra/auth/jwt-verifier.ts; para pasar a otro proveedor
// de identidad (JWKS, sesiones) se cambia ese adaptador, no las rutas.
export type TokenVerifier = (token: string) => Promise<Principal | null>;
