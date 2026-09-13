#!/usr/bin/env bash
set -euo pipefail

HTML_OUT="docs/webstack-agent-harness-spec.html"
PDF_OUT="docs/webstack-agent-harness-spec.pdf"

echo "1. Generando especificación técnica en HTML..."
cat << 'HTMLEOF' > "$HTML_OUT"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Webstack Agent Harness — Especificación Técnica & Manual de Arquitectura</title>
  <style>
    @page {
      size: A4;
      margin: 20mm 15mm 20mm 15mm;
      @bottom-right {
        content: counter(page);
      }
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #1a202c;
      line-height: 1.5;
      font-size: 11pt;
      margin: 0;
      padding: 0;
    }
    .cover {
      page-break-after: always;
      display: flex;
      flex-direction: column;
      justify-content: center;
      min-height: 85vh;
      border-bottom: 3px solid #2b6cb0;
    }
    h1 { font-size: 26pt; color: #1a365d; margin-bottom: 0.2em; }
    h2 { font-size: 16pt; color: #2b6cb0; border-bottom: 1.5px solid #e2e8f0; padding-bottom: 4px; margin-top: 2em; page-break-after: avoid; }
    h3 { font-size: 13pt; color: #2d3748; margin-top: 1.4em; page-break-after: avoid; }
    p { margin: 0.6em 0; text-align: justify; }
    .subtitle { font-size: 14pt; color: #4a5568; margin-bottom: 2em; }
    .badge { display: inline-block; background: #edf2f7; color: #2d3748; padding: 2px 8px; border-radius: 4px; font-size: 9pt; font-family: monospace; }
    table { width: 100%; border-collapse: collapse; margin: 1.2em 0; font-size: 10pt; page-break-inside: avoid; }
    th, td { border: 1px solid #cbd5e0; padding: 8px 10px; text-align: left; }
    th { background: #f7fafc; color: #2d3748; font-weight: 600; }
    code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 9.5pt; background: #edf2f7; padding: 2px 4px; border-radius: 3px; }
    pre { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 12px; font-size: 8.5pt; font-family: monospace; overflow-x: auto; page-break-inside: avoid; }
    .callout { background: #ebf8ff; border-left: 4px solid #3182ce; padding: 10px 14px; margin: 1.2em 0; border-radius: 0 4px 4px 0; font-size: 10pt; page-break-inside: avoid; }
    .callout-warn { background: #fffaf0; border-left-color: #dd6b20; }
    .page-break { page-break-before: always; }
  </style>
</head>
<body>

  <!-- PORTADA -->
  <div class="cover">
    <span class="badge">SPECIFICATION V1.0 • FAIL-CLOSED</span>
    <h1>Webstack Agent Harness</h1>
    <div class="subtitle">Arnés de Ingeniería de Software para Desarrollo Guiado por Agentes Autónomos</div>
    <p><strong>Stack Tecnológico:</strong> Node.js 22 LTS, TypeScript 5, Fastify, TypeBox, Drizzle ORM, PostgreSQL 16 (tmpfs), Vitest, Stryker Mutator, fast-check, Schemathesis, Gitleaks.</p>
    <p><strong>Entorno Operativo:</strong> WSL2 / Ubuntu Linux con Docker Compose.</p>
    <p><strong>Filosofía de Arquitectura:</strong> Aislamiento estricto de capas, ejecución atómica, verificación determinista y bloqueo preventivo ante la ausencia de dependencias.</p>
  </div>

  <!-- SECCIÓN 1 -->
  <h2>1. Filosofía Operativa y Diseño Fail-Closed</h2>
  <p>El arnés responde a un problema fundamental en la generación de software asistida por inteligencia artificial: los agentes tienden al <em>sobreajuste</em> (tampering), relajan aserciones cuando encuentran obstáculos y cometen errores silentes de integración si el sistema no bloquea la ejecución de forma binaria.</p>
  
  <div class="callout">
    <strong>Principio de Falla Cerrada (Fail-Closed):</strong> Si una herramienta de seguridad o comprobación no está instalada, no está configurada o arroja un código de salida distinto de cero, el pipeline aborta de inmediato. Nunca se asume éxito por omisión.
  </div>

  <p>Para asegurar la velocidad de iteración sin degradar la confiabilidad, la verificación se estructura en <strong>cuatro niveles concéntricos</strong> coordinados mediante <code>justfile</code>:</p>

  <table>
    <thead>
      <tr>
        <th>Nivel</th>
        <th>Comando</th>
        <th>Objetivo Temporal</th>
        <th>Propósito y Alcance</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Nivel 1</strong></td>
        <td><code>just gauntlet-fast</code></td>
        <td>&lt; 5 segundos</td>
        <td>Hook de pre-commit. Validación de tipos (<code>tsc</code>), linter (<code>eslint</code>), pruebas unitarias y análisis de secretos en staging (Gitleaks).</td>
      </tr>
      <tr>
        <td><strong>Nivel 2</strong></td>
        <td><code>just gauntlet</code></td>
        <td>&lt; 30 segundos</td>
        <td>Verificación estructural. Arquitectura de módulos (<code>depcruise</code>), Postgres en RAM, detección de schema drift, reversibilidad de migraciones (Up/Down), matriz de auth y tests de integración con detector N+1.</td>
      </tr>
      <tr>
        <td><strong>Nivel 3</strong></td>
        <td><code>just gauntlet-full</code></td>
        <td>&lt; 2-3 minutos</td>
        <td>Puerta de enlace pre-merge. Property testing (1,000 iteraciones), fuzzing de contratos OpenAPI (Schemathesis), semillas deterministas (SHA-256), suite hold-out sellada y análisis de mutación del diff (Stryker).</td>
      </tr>
      <tr>
        <td><strong>Nivel 4</strong></td>
        <td><code>just audit</code></td>
        <td>Auditoría nocturna</td>
        <td>Análisis de mutación exhaustivo sobre todo el código fuente del proyecto.</td>
      </tr>
    </tbody>
  </table>

  <!-- SECCIÓN 2 -->
  <div class="page-break"></div>
  <h2>2. Catálogo y Especificación de los 8 Gates</h2>

  <h3>Gate 1: Migraciones Reversibles Up/Down</h3>
  <p>Garantiza que toda modificación DDL en la base de datos pueda revertirse limpiamente sin dejar residuos estructurales. El script <code>scripts/test-migrations-reversible.sh</code> aplica en una base efímera todas las migraciones <code>.sql</code>, luego aplica los rollbacks <code>.down.sql</code> en orden inverso, y compara mediante <code>pg_dump</code> que el esquema resultante sea idéntico al original antes de volver a aplicar las migraciones.</p>

  <h3>Gate 2: Detección de Schema Drift</h3>
  <p>Evita que existan modelos en TypeScript (<code>src/infra/db/schema.ts</code>) sin migración SQL versionada. El script <code>scripts/test-db-drift.sh</code> toma una instantánea del estado de Git, corre <code>drizzle-kit generate</code> y compara si el árbol de trabajo cambió. Si se generan archivos nuevos o se altera el diario de migraciones, aborta con código 1.</p>

  <h3>Gate 3: Conformidad de Contratos OpenAPI (Fuzzing con Schemathesis)</h3>
  <p>Valida que la especificación OpenAPI generada por Fastify coincida estrictamente con el comportamiento real del servidor. Schemathesis corre en contenedor Docker enviando casos límite aleatorios. Verifica que no existan errores 500, que todos los códigos devueltos (ej. 200, 401) estén declarados y que los payloads cumplan con los esquemas TypeBox.</p>

  <h3>Gate 4: Matriz de Autenticación Fail-Closed</h3>
  <p>Prueba de arquitectura ejecutada en Vitest (<code>tests/architecture/auth-matrix.test.ts</code>). Intercepta el hook <code>onRoute</code> de Fastify y analiza todas las rutas registradas. Si una ruta no cuenta con el middleware <code>requireAuth</code> y tampoco está marcada explícitamente como <code>config.isPublic = true</code>, el guantelete falla.</p>

  <h3>Gate 5: Integridad de Hold-Out Tests</h3>
  <p>Previene la alteración maliciosa o descuidada de pruebas por parte de un agente (<em>test tampering</em>). La suite <code>tests/holdout/</code> contiene aserciones de invariantes de seguridad. El archivo <code>.holdout.sha256</code> contiene la firma criptográfica de los tests. Si el script <code>scripts/test-holdouts.sh</code> detecta un cambio de un solo bit en la suite, bloquea el avance.</p>

  <h3>Gate 6: Detección de Consultas N+1</h3>
  <p>Instrumenta el cliente <code>postgres.js</code> mediante un listener de depuración síncrono. La función <code>assertMaxQueries(max, callback)</code> audita el número exacto de sentencias SQL disparadas por una operación. Si un agente resuelve un listado iterando en bucle en vez de usar consultas por lotes (batch/inArray), el test falla mostrando la traza de las consultas.</p>

  <h3>Gate 7: Determinismo de Seeds y Fixtures</h3>
  <p>Garantiza que la base de datos de desarrollo y testing sea reproducible bit a bit. El script <code>scripts/test-seed-determinism.sh</code> siembra dos bases de datos efímeras independientes y calcula el SHA-256 de las sentencias <code>INSERT</code> extraídas mediante <code>pg_dump</code>. Prohíbe identificadores aleatorios o fechas dinámicas (<code>Date.now()</code>).</p>

  <h3>Gate 8: Prevención de Fuga de Credenciales</h3>
  <p>Integrado directamente en <code>gauntlet-fast</code>. Evalúa cada commit contra Gitleaks (<code>gitleaks protect --staged</code>). Si se detectan tokens de AWS, claves privadas o JWTs en el área de preparación, el hook aborta antes de ejecutar el transpilador.</p>

  <!-- SECCIÓN 3 -->
  <div class="page-break"></div>
  <h2>3. Topología de Archivos y Componentes del Sistema</h2>
  <pre>
.
├── .dependency-cruiser.js          # Reglas de aislamiento hexagonal de capas
├── .env.example                    # Plantilla de variables de entorno
├── .holdout.sha256                 # Sello criptográfico SHA-256 de invariantes (Gate 5)
├── docker-compose.yml              # PostgreSQL 16 con data montada en tmpfs (RAM)
├── drizzle.config.ts               # Configuración de Drizzle Kit
├── justfile                        # Orquestador declarativo de los 4 niveles de validación
├── package.json                    # Scripts npm y dependencias estrictas
├── scripts/
│   ├── mutate-diff.sh              # Stryker enfocado exclusivamente en diff git vs main
│   ├── test-contracts.sh           # Levantamiento de Fastify + Fuzzing Schemathesis (Gate 3)
│   ├── test-db-drift.sh            # Comprobación de deriva de esquema (Gate 2)
│   ├── test-holdouts.sh            # Validador de firma e integridad de hold-outs (Gate 5)
│   ├── test-migrations-reversible.sh # Verificación de Up/Down sin residuos (Gate 1)
│   └── test-seed-determinism.sh    # Verificación de identidad criptográfica en seeds (Gate 7)
├── src/
│   ├── domain/                     # Lógica pura de negocio y funciones invariantes
│   ├── http/
│   │   ├── app.ts                  # Fastify con TypeBox, Swagger y hook de autenticación
│   │   └── server.ts               # Entrypoint HTTP del servidor
│   └── infra/
│       └── db/
│           ├── client.ts           # Cliente Drizzle + postgres.js con query listener (Gate 6)
│           ├── migrate.ts          # Ejecutor programático de migraciones Drizzle
│           ├── schema.ts           # Esquema DDL en TypeScript
│           └── seed.ts             # Sembrador de datos determinista (Gate 7)
└── tests/
    ├── architecture/               # Matriz de autenticación (Gate 4)
    ├── helpers/query-counter.ts    # Utilidad de aserción de conteo SQL (Gate 6)
    ├── holdout/                    # Invariantes sellados anti-tampering (Gate 5)
    ├── integration/                # Tests contra Postgres en RAM (Gate 6)
    ├── property/                   # Tests basados en propiedades con fast-check
    └── unit/                       # Pruebas unitarias de ejecución instantánea
  </pre>

  <h2>4. Guía de Operación para Agentes Autónomos</h2>
  <p>Al despachar tareas a un agente de código dentro de este repositorio, el agente debe operar bajo el siguiente flujo de trabajo:</p>
  <ol>
    <li><strong>Aislamiento de Entorno:</strong> Operar en una rama de trabajo secundaria creada a partir de <code>main</code>.</li>
    <li><strong>Ciclo Rápido:</strong> Correr <code>just gauntlet-fast</code> tras cada modificación de archivo.</li>
    <li><strong>Persistencia de Datos:</strong> Al tocar <code>schema.ts</code>, ejecutar obligatoriamente <code>just db-generate</code>, escribir el archivo <code>.down.sql</code> complementario y verificar con <code>just gauntlet</code>.</li>
    <li><strong>Exposición de Endpoints:</strong> Todo endpoint registrado en <code>src/http/app.ts</code> debe declarar su esquema TypeBox, el contrato <code>401</code> si requiere credenciales, o <code>config: { isPublic: true }</code> si es público.</li>
    <li><strong>Criterio de Aceptación:</strong> Una tarea sólo se considera concluida cuando el agente reporte la salida de <code>just gauntlet-full</code> con código de salida 0.</li>
  </ol>

</body>
</html>
HTMLEOF

echo "2. Compilando PDF a través del motor de renderizado..."
# Detección de binarios de Chromium/Edge (tanto en Linux como en Windows a través de WSL)
CHROME_BIN=""

if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROME_BIN="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="chromium"
elif [ -f "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" ]; then
  CHROME_BIN="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
elif [ -f "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" ]; then
  CHROME_BIN="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
fi

if [ -n "$CHROME_BIN" ]; then
  echo "Motor detectado: $CHROME_BIN"
  "$CHROME_BIN" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$PDF_OUT" "$HTML_OUT" 2>/dev/null || true
  if [ -f "$PDF_OUT" ]; then
    echo "✔ Documento PDF compilado con éxito: $PDF_OUT"
    exit 0
  fi
fi

echo "Nota: Motor headless no disponible directamente en CLI."
echo "El documento HTML de alta fidelidad está listo en: $HTML_OUT"
echo "Puedes abrirlo en tu navegador y guardarlo como PDF (Ctrl+P -> Guardar como PDF)."
