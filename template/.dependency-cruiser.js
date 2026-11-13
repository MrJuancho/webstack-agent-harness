// Capas, de adentro hacia afuera -- cada una solo puede importar de las
// que tiene a su izquierda:
//
//   domain  <-  application  <-  infra, http
//
// `src/composition.ts` y `src/main.ts` quedan fuera de las reglas a
// propósito: la raíz de composición (el único archivo que conecta puertos
// con adaptadores) y el punto de entrada del proceso (valida la
// configuración y recién entonces carga el resto).
// Ver AGENTS.md, "Convención de capas". scripts/verify-template.sh (en el
// repo del template) prueba que cada regla de capa de verdad muerde.
/** @type {import('dependency-cruiser').IConfiguration} */
export default {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Prohibir dependencias circulares en todo el proyecto',
      from: {},
      to: { circular: true }
    },
    {
      name: 'domain-isolation',
      severity: 'error',
      comment: 'El dominio no depende de ninguna otra capa',
      from: { path: '^src/domain' },
      to: { path: '^src/(application|infra|http|composition|main)' }
    },
    {
      name: 'application-isolation',
      severity: 'error',
      comment:
        'Los casos de uso solo dependen del dominio y de sus propios puertos; infra implementa esos puertos, no al revés',
      from: { path: '^src/application' },
      to: { path: '^src/(infra|http|composition|main)' }
    },
    {
      name: 'infra-cannot-access-http',
      severity: 'error',
      comment: 'La infraestructura no puede depender de los adaptadores HTTP',
      from: { path: '^src/infra' },
      to: { path: '^src/(http|composition|main)' }
    },
    {
      name: 'http-cannot-access-infra',
      severity: 'error',
      comment:
        'Las rutas hablan con la aplicación, no con la base: los adaptadores reales llegan ya conectados desde src/composition.ts',
      from: { path: '^src/http' },
      to: { path: '^src/(infra|main)' }
    }
  ],
  options: {
    doNotFollow: {
      path: 'node_modules'
    },
    tsPreCompilationDeps: true,
    tsConfig: {
      fileName: 'tsconfig.json'
    }
  }
};
