// eslint.google.cjs — claude-tdd-pro Google-style baseline.
//
// Layered on top of `eslint-config-google` (the official Google rule
// set) and Google's TypeScript-specific recommendations.
//
// Install (in target repo):
//   npm i -D eslint eslint-config-google @typescript-eslint/parser \
//          @typescript-eslint/eslint-plugin eslint-plugin-import \
//          eslint-plugin-jsdoc eslint-plugin-prettier prettier
//
// Then `cp this -> .eslintrc.cjs` (or merge with existing).
// The /init-guardrails command does this automatically.

module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: { ecmaVersion: 2022, sourceType: 'module' },
  plugins: ['@typescript-eslint', 'import', 'jsdoc', 'prettier'],
  extends: [
    'eslint:recommended',
    'google',
    'plugin:@typescript-eslint/recommended',
    'plugin:import/recommended',
    'plugin:import/typescript',
    'plugin:jsdoc/recommended',
    'prettier',
  ],
  env: { browser: true, node: true, es2022: true },
  rules: {
    // RUBRIC.yaml g-ts-001
    '@typescript-eslint/naming-convention': [
      'error',
      { selector: 'default', format: ['camelCase'] },
      { selector: 'variable', format: ['camelCase', 'UPPER_CASE'] },
      { selector: 'parameter', format: ['camelCase'], leadingUnderscore: 'forbid' },
      { selector: 'typeLike', format: ['PascalCase'] },
      { selector: 'enumMember', format: ['UPPER_CASE'] },
    ],
    // g-ts-002
    'import/no-default-export': 'error',
    // g-ts-003
    'no-var': 'error',
    // g-ts-004
    'no-eval': 'error',
    // g-ts-005
    'eqeqeq': ['error', 'always', { null: 'ignore' }],
    // g-ts-006
    '@typescript-eslint/no-explicit-any': 'error',
    // g-ts-008
    'prefer-const': 'error',
    // g-ts-009
    '@typescript-eslint/no-throw-literal': 'error',
    // g-ts-010
    'no-debugger': 'error',
    // g-ts-011 — relax for non-public files; full strict on `src/**` only
    'jsdoc/require-jsdoc': [
      'warn',
      { publicOnly: true, require: { FunctionDeclaration: true, ClassDeclaration: true } },
    ],
    // g-ts-012
    'prettier/prettier': 'error',

    // Google JS guide additions not covered by `google` preset:
    'no-with': 'error',
    'no-implicit-coercion': ['error', { boolean: false, number: true, string: true }],
    'no-throw-literal': 'error',
    'one-var': ['error', 'never'],

    // Google TS guide: no-bracket-access for visibility bypass
    'dot-notation': 'error',
  },
  overrides: [
    {
      files: ['**/*.test.ts', '**/*.spec.ts', '**/*.test.tsx', '**/*.spec.tsx'],
      rules: {
        // Test files can use `any` for mock fixtures (with comment).
        '@typescript-eslint/no-explicit-any': 'warn',
        'jsdoc/require-jsdoc': 'off',
      },
    },
  ],
};
