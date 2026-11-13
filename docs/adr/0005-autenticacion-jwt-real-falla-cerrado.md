# ADR-0005: `requireAuth` verifica un JWT de verdad y falla cerrado

**Estado:** Aceptado
**Fecha:** 2026-11-13

## Contexto

`requireAuth` era un centinela: aceptaba cualquier header que empezara con `Bearer `,
sin verificar nada. Gate 4 (la matriz de auth) comprueba que cada ruta DECLARA
`requireAuth` o `isPublic`, no que la protección sea real -- así que un proyecto
generado pasaba todos los gates con una API que cualquiera podía usar enviando
`Authorization: Bearer x`. Nada avisaba si ese centinela llegaba a producción.

## Decisión

1. **Verificación real**: JWT HS256 firmado con `JWT_SECRET`, con `sub` y `exp`
   obligatorios y el algoritmo fijo (un token `alg: none` o HS512 se rechaza). Librería
   [`jose`](https://github.com/panva/jose), fijada a una versión exacta.
2. **Falla cerrado, sin valor por defecto**: `buildApp` lanza si `JWT_SECRET` falta o
   tiene menos de 32 caracteres -- el servidor no llega a escuchar. No hay secreto "de
   desarrollo" en el código: un valor conocido que llega a producción por un `NODE_ENV`
   mal puesto es el accidente que esto evita.
3. **`scripts/worktree-env.sh` genera el secreto local** (256 bits aleatorios, en
   `.env.local`, gitignored) y lo conserva entre corridas.
4. **Puerto `TokenVerifier`** en `src/application/auth/ports.ts`; el adaptador JWT vive
   en `src/infra/auth/`. Las rutas solo conocen el puerto, así que pasar a JWKS/OIDC es
   reemplazar un archivo.
5. **Gate 4 ahora prueba que la protección es real**: contra la app con el cableado
   real, exige `200` con un token válido y `401` con uno que no es JWT, uno firmado con
   otro secreto y uno vencido.
6. **Gate 3 confirma que su token entra** antes de correr Schemathesis: como `401` está
   documentado en el contrato, un token rechazado dejaría la corrida en verde sin haber
   auditado ninguna ruta protegida.

El proyecto verifica tokens; no los emite. `just dev-token` firma uno de 1 hora con el
secreto local para pruebas manuales y para Gate 3, y se niega a correr con
`NODE_ENV=production`.

## Consecuencias

- Todo despliegue necesita `JWT_SECRET` en su entorno, o el servidor no arranca.
- HS256 con secreto compartido es el punto de partida más simple que es seguro de
  verdad, no el destino: un proyecto con proveedor de identidad externo debería
  reemplazar el adaptador por verificación con JWKS.
- Los hold-outs sellados siguen pasando sin cambios (verificado corriendo `just
  gauntlet-full`; el agente no puede leerlos).
- Pendiente, fuera de este cambio: `requireAuth` corre en `preHandler` (lo exigen Gate 4
  y la constitución), que en Fastify va DESPUÉS de validar el esquema. Un request sin
  token con cuerpo inválido recibe `400`, no `401`. Moverlo a `onRequest` requiere
  cambiar Gate 4 y la constitución, y confirmar con un humano que los hold-outs no
  dependen de `preHandler`.
