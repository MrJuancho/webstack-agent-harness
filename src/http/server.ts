import { buildApp } from './app.js';

const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? '0.0.0.0';

const app = await buildApp();

try {
  await app.listen({ port: PORT, host: HOST });
  console.log(`Servidor HTTP activo en http://${HOST}:${PORT}`);
} catch (err) {
  console.error('Error al iniciar el servidor:', err);
  process.exit(1);
}
