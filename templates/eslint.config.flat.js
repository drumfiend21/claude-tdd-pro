// Reference ESLint flat config (ESLint 9+).
// Convergent shape from claude-tdd-pro: strict where it matters, tuned to
// not produce false-positive noise.
//
// USE FOR: Node-only projects (drop the react/react-hooks plugin sections).
// See `eslint.config.flat.react.js` for the React-flavored variant.
//
// Required deps:
//   npm i -D eslint @eslint/js globals prettier eslint-config-prettier eslint-plugin-security

import js from '@eslint/js';
import globals from 'globals';
import securityPlugin from 'eslint-plugin-security';
import prettierConfig from 'eslint-config-prettier';

export default [
  {
    ignores: ['node_modules/**', 'dist/**', 'build/**', 'coverage/**', '.audit/**'],
  },
  js.configs.recommended,
  securityPlugin.configs.recommended,
  prettierConfig,
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      'no-unused-vars': [
        'warn',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          // Caught errors named `_` or `_e` are intentional ignores
          // (the `catch (_) { /* expected */ }` pattern). Without this
          // every silent catch fires a warning.
          caughtErrorsIgnorePattern: '^_',
        },
      ],
      'no-console': 'off',
      'no-var': 'error',
      'prefer-const': 'error',
      'object-shorthand': 'warn',
      'no-empty': ['error', { allowEmptyCatch: true }],
      // Security plugin tuning:
      'security/detect-object-injection': 'off',
      // Disabled: every `path.join(__dirname, ...)` triggers this. Pure
      // noise for codebases where no user input reaches the filesystem.
      'security/detect-non-literal-fs-filename': 'off',
      'security/detect-non-literal-regexp': 'warn',
      'security/detect-unsafe-regex': 'warn',
    },
  },
  {
    files: ['tests/**/*.js', '**/*.test.js'],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
  },
];
