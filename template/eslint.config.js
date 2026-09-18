import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: {
          allowDefaultProject: [
            '.dependency-cruiser.js',
            '*.config.js',
            '*.config.ts',
            'vitest.config.domain.ts',
          ],
        },
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }
      ],
    },
  },
  {
    files: ['**/*.js', '**/*.mjs', 'tests/**/*.ts', 'vitest.config.ts', 'vitest.config.domain.ts'],
    ...tseslint.configs.disableTypeChecked,
  },
  {
    // El dominio no lee ambiente no determinista -- ni el reloj de pared
    // ni una fuente de aleatoriedad. Una sola lectura intermitente rompe
    // la reproducibilidad de las property tests (fast-check) y hace que
    // los mutantes de Stryker corran distinto entre corridas. El tiempo y
    // la aleatoriedad entran como parámetros explícitos, no se leen del
    // entorno. Ver AGENTS.md, "Convención de capas".
    //
    // `files` incluye los *.test.ts co-ubicados en src/domain/ a
    // propósito -- los tests del dominio deben ser tan deterministas
    // como el dominio mismo.
    files: ['src/domain/**/*.ts'],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector: "MemberExpression[object.name='Date'][property.name='now']",
          message:
            'El dominio no lee el reloj. Recibe el instante como parámetro explícito desde la capa de aplicación (ej. `function foo(now: Date) { ... }`), no lo leas con Date.now().',
        },
        {
          selector: 'NewExpression[callee.name=\'Date\'][arguments.length=0]',
          message:
            'El dominio no lee el reloj. `new Date()` sin argumentos captura el instante actual -- recibe el instante como parámetro explícito y constrúyelo con `new Date(valorRecibido)`.',
        },
        {
          selector: "MemberExpression[object.name='performance'][property.name='now']",
          message:
            'El dominio no lee el reloj de alta resolución. Recibe la duración o el instante ya medidos como parámetro explícito desde la capa de aplicación.',
        },
        {
          selector: "MemberExpression[object.name='Math'][property.name='random']",
          message:
            'El dominio no genera aleatoriedad no determinista. Recibe la fuente de aleatoriedad (valor, semilla o generador) como parámetro explícito desde la capa de aplicación.',
        },
        {
          selector: "MemberExpression[object.name='process'][property.name='hrtime']",
          message:
            'El dominio no lee el reloj de alta resolución del proceso. Recibe la duración o el instante ya medidos como parámetro explícito desde la capa de aplicación.',
        },
        {
          selector:
            "CallExpression[callee.object.name='Intl'][callee.property.name='DateTimeFormat']",
          message:
            'El dominio no lee la zona horaria del entorno. Recibe la zona horaria (o el valor ya formateado) como parámetro explícito desde la capa de aplicación.',
        },
      ],
    },
  },
  {
    ignores: ['dist/', 'node_modules/', 'coverage/'],
  }
);
