import { describe, it, expect } from 'vitest';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

// Levanta el servidor REAL como proceso aparte (mismo comando que
// `pnpm start`) y le manda señales, como lo haría Docker o Kubernetes.
// No hay forma de probar el apagado ordenado desde adentro del proceso.

interface RunningServer {
  readonly port: number;
  readonly output: () => string;
  readonly signalAndWait: (signal: NodeJS.Signals) => Promise<number | null>;
}

async function startServer(env: Record<string, string>): Promise<RunningServer> {
  const child = spawn('node', ['--import', 'tsx', 'src/main.ts'], {
    // PORT=0: el sistema elige un puerto libre; se lee del log de arranque.
    env: { ...process.env, HOST: '127.0.0.1', PORT: '0', LOG_LEVEL: 'info', ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  const exited = once(child, 'exit') as Promise<[number | null]>;

  const port = await new Promise<number>((resolve, reject) => {
    const onData = (chunk: Buffer) => {
      output += chunk.toString();
      const match = /Server listening at http:\/\/127\.0\.0\.1:(\d+)/.exec(output);
      if (match) {
        resolve(Number(match[1]));
      }
    };
    child.stdout.on('data', onData);
    child.stderr.on('data', onData);
    void exited.then(([code]) =>
      reject(new Error(`el servidor salió (código ${code}) antes de escuchar:\n${output}`))
    );
  });

  return {
    port,
    output: () => output,
    signalAndWait: async (signal) => {
      child.kill(signal);
      const [code] = await exited;
      return code;
    },
  };
}

describe('apagado ordenado del servidor', () => {
  it.each(['SIGTERM', 'SIGINT'] as const)(
    'con %s deja de escuchar, cierra recursos y sale con código 0',
    async (signal) => {
      const server = await startServer({});
      const health = await fetch(`http://127.0.0.1:${server.port}/health`);
      expect(health.status).toBe(200);

      const exitCode = await server.signalAndWait(signal);

      // 0 = apagado ordenado. `null` significaría que la señal mató al
      // proceso sin que el manejador corriera.
      expect(exitCode).toBe(0);
      expect(server.output()).toContain('Shutdown requested');
      await expect(fetch(`http://127.0.0.1:${server.port}/health`)).rejects.toThrow();
    },
    20_000
  );

  it('con configuración inválida no arranca: sale con 1 y lista los problemas', async () => {
    await expect(startServer({ PORT: 'abc', LOG_LEVEL: 'verbose' })).rejects.toThrow(
      /código 1[\s\S]*Configuración inválida \(2 problema\(s\)\)[\s\S]*PORT="abc"[\s\S]*LOG_LEVEL="verbose"/
    );
  }, 20_000);
});
