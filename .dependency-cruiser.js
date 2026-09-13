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
      comment: 'El dominio no puede depender de infra ni de http',
      from: { path: '^src/domain' },
      to: { path: '^src/(infra|http)' }
    },
    {
      name: 'infra-cannot-access-http',
      severity: 'error',
      comment: 'La infraestructura no puede depender de los adaptadores HTTP',
      from: { path: '^src/infra' },
      to: { path: '^src/http' }
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
