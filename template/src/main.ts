import { ConfigError, loadEnvFiles, readServerConfig } from './infra/config.js';

// Punto de entrada del proceso (`pnpm start`, y `node dist/main.js` en la
// imagen). Valida TODA la configuración antes de cargar el resto de la
// app, y recién entonces la importa.
//
// El `import()` dinámico es a propósito: src/infra/db/client.ts abre su
// pool al importarse, y con un import estático eso correría ANTES que
// esta validación -- el proceso moriría con el primer problema y un stack
// trace, en vez de la lista completa de lo que falta.
try {
  loadEnvFiles();
  const config = readServerConfig(process.env);
  const { startServer } = await import('./http/server.js');
  await startServer(config);
} catch (error) {
  // Falla de arranque: mensaje legible y exit 1. Un ConfigError ya trae
  // la lista de problemas; cualquier otro error (puerto ocupado, un bug)
  // va completo, con stack. Por console.error porque el logger puede no
  // existir todavía.
  console.error(error instanceof ConfigError ? error.message : error);
  process.exit(1);
}
