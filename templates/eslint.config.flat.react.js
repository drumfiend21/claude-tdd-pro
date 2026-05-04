// Reference ESLint flat config for React projects (ESLint 9+).
//
// Note: ESLint 10 currently incompatible with eslint-plugin-react peer-deps.
// Pin to eslint@^9 in this case.
//
// Required deps:
//   npm i -D eslint@^9 @eslint/js@^9 globals prettier eslint-config-prettier \
//            eslint-plugin-react eslint-plugin-react-hooks

import js from '@eslint/js';
import globals from 'globals';
import reactPlugin from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import prettierConfig from 'eslint-config-prettier';

export default [
  {
    ignores: ['node_modules/**', 'dist/**', 'build/**', 'coverage/**', '.audit/**', 'public/**'],
  },
  js.configs.recommended,
  prettierConfig,
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
      },
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    plugins: {
      react: reactPlugin,
      'react-hooks': reactHooks,
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      'no-unused-vars': [
        'warn',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_',
        },
      ],
      'no-console': 'off',
      'no-var': 'error',
      'no-empty': ['error', { allowEmptyCatch: true }],
      // Stylistic only — modern React renders ' and " in text without
      // ambiguity. The rule fires on natural English prose.
      'react/no-unescaped-entities': 'off',
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      'react/jsx-uses-react': 'off',
      // Phase 3 covers — these are warnings during remediation,
      // promote to errors once the codebase is clean.
      'react-hooks/exhaustive-deps': 'warn',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/set-state-in-effect': 'warn',
      'no-useless-escape': 'warn',
      'no-misleading-character-class': 'warn',
      'no-dupe-else-if': 'warn',
      'prefer-const': 'warn',
    },
    settings: {
      react: { version: 'detect' },
    },
  },
];
