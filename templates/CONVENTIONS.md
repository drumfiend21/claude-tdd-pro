# Project conventions

> **Edit this file to match your project.** This is the canonical
> source for AI-tool-agnostic project conventions. Run `/sync-rules`
> from `claude-tdd-pro` to regenerate sister files for Cursor,
> Copilot, Aider, Continue, Windsurf, and the cross-tool `AGENTS.md`
> standard.
>
> Cross-tool layout (universal pattern across Cursor, Copilot,
> Continue, Windsurf as of late 2026): one root rules file plus
> per-area glob-scoped overrides under `conventions/`.

## Tech stack

<!-- One paragraph. The single most useful section per Copilot's tutorial. -->

- Language: TypeScript 5.x
- Framework:
- Runtime: Node 20 LTS
- Package manager: npm
- Testing: vitest + @testing-library/react + @testing-library/jest-dom
- Lint: ESLint flat config + Prettier
- Build:

## Build & run

<!-- The cheatsheet that prevents "what's the test command" cycles. -->

| Action | Command |
|---|---|
| Install | `npm install` |
| Dev server | `npm run dev` |
| Build | `npm run build` |
| Test | `npm test` |
| Test (watch) | `npm run test:watch` |
| Lint | `npm run lint` |
| Format | `npm run format` |
| Typecheck | `npm run typecheck` |

## Style

- Follow [Google JS/TS style guide](https://google.github.io/styleguide/tsguide.html) where the project doesn't override it.
- 2-space indent, single quotes, trailing commas, 100-col line limit (overrides Google's 80).
- Function declarations for named functions; arrow functions for callbacks.
- `for…of` for arrays; `Object.entries()` for dicts.
- Test names read as specs: `it('is disabled when value is empty')`.

## Architecture

<!-- ADRs / module boundaries / data flow. Link to ADRs in adr/ if you have them. -->

- Pure logic in `src/lib/`, hooks in `src/hooks/`, React components in `src/components/`.
- API client surface lives in `src/lib/api.js` — single fetch wrapper with `AbortController` support.
- Tests live next to the file they test (`Foo.jsx` ↔ `Foo.test.jsx`), not in a `__tests__/` mirror.

## Preferred libraries

<!-- Aider-style: "Prefer X over Y". Concrete pin per choice. -->

- HTTP: native `fetch` (with `AbortController`); no axios.
- State: React hooks; Zustand for cross-tree state if needed.
- Validation: zod.
- Dates: native `Intl` + `Temporal` polyfill where unavoidable; no moment.

## Anti-patterns (NEVER do these)

<!-- Cursor pattern: terse, imperative refusals.
     Strong language is intentional — high-signal for the model. -->

- **NEVER** use `var`. Use `const` by default, `let` when reassigning.
- **NEVER** write `function() {…}` expressions; use arrow functions for callbacks, function declarations for named functions.
- **NEVER** use default exports; always named.
- **NEVER** disable an ESLint rule inline without a comment explaining why.
- **NEVER** use `any` in TypeScript without a `// eslint-disable-next-line` and an inline justification.
- **NEVER** delete a test to make CI pass. If a test fails, fix the code or fix the test deliberately and explain the change.
- **NEVER** swap React for Preact "for performance" — profile first.
- **NEVER** run `npm audit fix --force` (semver-bump risk).
- **NEVER** auto-commit fixes from CI back to the branch.
- **NEVER** commit `.env`, `id_rsa`, `*.pem`, AWS credentials, or anything matching the secret-scan regex.
- **NEVER** use `--dangerously-skip-permissions` on Claude Code.
- **NEVER** outsource your understanding to the model — read every line you commit.

## Testing

- Strict assertions only: `getByRole`, exact counts, jest-dom matchers (`toBeInTheDocument`, `toBeDisabled`, `toHaveAttribute`).
- No `queryAllByText(...).length > 0` — that passes against broken UIs.
- Tests live with the code they test (sibling file).
- Two tiers: isolated unit tests (per file) PLUS integration regression tests (cross-cutting flows).
- Always `afterEach(cleanup)` registered globally when using `@testing-library/react` + vitest with `globals: false`.
- Bug-as-failing-test: every fix ships with the test that would have caught the bug.

## Verification steps

<!-- Cursor pattern: "after writing X, check Y." Self-checks the model
     should run before declaring done. -->

After writing or editing source:
1. Run the relevant unit test file. Confirm green.
2. Run the full suite: `npm test`.
3. Run `npm run lint` and `npm run typecheck`. 0 errors required.
4. If a UI change: take a screenshot for the PR.
5. If touching the API client: confirm there's an `AbortController`
   path for the fetch.

After every commit:
1. Run `bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/secret-scan.sh` (auto on commit if Husky hook installed).

## Project-specific notes

<!-- Anything else a new contributor needs to know. -->

(Empty.)

---

## How to use this file

- **Claude Code**: this file is read automatically by `claude-tdd-pro` skills via `${CLAUDE_PROJECT_DIR}/CONVENTIONS.md`.
- **Cursor**: `/sync-rules` regenerates `.cursor/rules/conventions.mdc` from this file.
- **GitHub Copilot**: `/sync-rules` regenerates `.github/copilot-instructions.md` from this file.
- **Aider**: `/sync-rules` patches `.aider.conf.yml` to include this file as `read:`.
- **Windsurf**: `/sync-rules` regenerates `.windsurfrules`.
- **Cross-tool standard**: `/sync-rules` regenerates `AGENTS.md`.

Edit ONE file (this one). Sister files are regenerated, never edited by hand.
