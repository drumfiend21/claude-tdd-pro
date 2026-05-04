---
name: init-guardrails
description: Phase 1 setup on a fresh project. Installs ESLint flat config + Prettier + tsconfig checkJs + Husky + lint-staged + Vitest with strict cleanup. No behavior change to existing code beyond a one-time prettier pass (committed separately).
---

The user wants to set up the toolchain (Phase 1 of remediation).

Load the `phase-1-guardrails` skill and follow it precisely. Use the
templates in `${CLAUDE_PLUGIN_ROOT}/templates/`.

Order of operations:

1. Detect existing setup; ASK before overwriting any pre-existing
   ESLint/Prettier/tsconfig.
2. Install dev dependencies.
3. Drop in templates from `${CLAUDE_PLUGIN_ROOT}/templates/`:
   - `eslint.config.flat.js` (or `.react.js` if React detected)
   - `prettierrc.json` → `.prettierrc.json`
   - `tsconfig.checkjs.json` → `tsconfig.json`
   - `vitest.config.with-cleanup.js` → `vitest.config.js`
   - `test-setup.js` → `src/__tests__/setup.js`
4. Add scripts (`lint`, `format`, `typecheck`, `test`, `prepare`,
   `lint-staged` config) to package.json.
5. `npx husky init` + replace `.husky/pre-commit` with
   `npx lint-staged`.
6. Run `npx prettier --write .` and commit as a SEPARATE
   formatting-only commit.
7. Verify lint / format / typecheck / test all run; capture baseline.
8. Final guardrails commit referencing REMEDIATION.md.

Do NOT proceed to Phase 2 (tests) or any other work in the same
session unless the user explicitly asks. Phase 1 is the foundation;
keep its commit scope tight.
