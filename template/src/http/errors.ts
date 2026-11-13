import { Type, type Static } from '@sinclair/typebox';

// Esquema estándar para errores de API
export const ErrorResponse = Type.Object(
  { error: Type.String() },
  { additionalProperties: false }
);
export type ErrorResponseType = Static<typeof ErrorResponse>;
