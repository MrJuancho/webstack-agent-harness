import { closeResources } from '../composition.js';
import { buildApp } from './app.js';

// Levanta la app y la apaga de forma ordenada cuando el orquestador lo
// pide. Lo llama src/main.ts con la configuración ya validada.

const SHUTDOWN_TIMEOUT_MS = 10_000;

export interface StartServerOptions {
  readonly host: string;
  readonly port: number;
  readonly logLevel: string;
}

export async function startServer(options: StartServerOptions): Promise<void> {
  const app = await buildApp({ logLevel: options.logLevel });

  let shuttingDown = false;
  const shutdown = async (signal: string): Promise<void> => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    app.log.info({ signal }, 'Shutdown requested: draining in-flight requests');

    // Si un request colgado no deja cerrar, no se espera para siempre: el
    // orquestador mandaría SIGKILL de todos modos, sin dejar rastro.
    const forceExit = setTimeout(() => {
      app.log.error({ timeoutMs: SHUTDOWN_TIMEOUT_MS }, 'Shutdown timed out: forcing exit');
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);
    forceExit.unref();

    try {
      // Deja de aceptar conexiones y espera los requests en curso; recién
      // después se cierra el pool de Postgres que esos requests usan.
      await app.close();
      await closeResources();
      process.exit(0);
    } catch (error) {
      app.log.error(error, 'Shutdown failed');
      process.exit(1);
    }
  };

  // SIGTERM: `docker stop`, Kubernetes, systemd. SIGINT: Ctrl+C en local.
  process.once('SIGTERM', () => void shutdown('SIGTERM'));
  process.once('SIGINT', () => void shutdown('SIGINT'));

  await app.listen({ port: options.port, host: options.host });
}
