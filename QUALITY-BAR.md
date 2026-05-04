# QUALITY-BAR.md

The single source of truth referenced by every skill, command, and agent
in this plugin. When in doubt about what "good" means, the answer is
here.

This document distills three things:

1. **Google's published engineering practices** ([eng-practices](https://google.github.io/eng-practices/)) — the canonical industry standard for code review.
2. **Google's language style guides** ([styleguide](https://google.github.io/styleguide/)) — the rules the model enforces in the code it writes.
3. **Public Meta engineering practices** — Phabricator/Sapling conventions, the React Rules of Hooks, etc., where they're publicly verifiable.

Plus session-derived rules from the `claude-tdd-pro` author's prior
codebase remediation work (test-first refactor pattern, strict-test
discipline, anti-patterns rejected from a prior tooling round).

The reference docs in [docs/standards/](docs/standards/) contain the full
extracts. This file is the "what to actually do" summary.

---

## The core principle

> Approve a change once it definitely improves overall code health, even
> if not perfect. Never accept a change that worsens code health.

Translates for the Claude agent into:

- **Always be writing tests first** when adding behavior. The test is the
  spec. Code without a test that fails-then-passes is suspect.
- **Always be reducing god-files** when extracting. The god-file should
  shrink with each commit, not grow.
- **Always be improving the test net** when fixing bugs. A bug means the
  test net failed to catch something; the fix includes the test that
  would have.

---

## Code-quality bar (what the model must ship)

### Tests

- **TDD red-green-refactor**: write a failing test, confirm it fails for
  the right reason, write minimum code to pass, refactor with tests
  still green. One scenario per cycle.
- **Strict assertions**: `getByRole('button', { name: /Save/ })` not
  `queryAllByText(/Save/).length > 0`. Exact counts where uniqueness is
  expected; `>= N` only when duplicates are inherent.
- **`afterEach(cleanup)` registered globally** when using
  `@testing-library/react` with vitest's `globals: false`. Without it,
  tests leak DOM and produce false-positive "found multiple elements"
  failures across test files.
- **Two tiers**: isolated unit tests (per file) PLUS integration
  regression tests (cross-cutting flows). Unit catches contract
  violations; integration catches wiring breaks.
- **Bug-as-failing-test**: when fixing a bug, write the test that
  captures the broken behavior FIRST, confirm it fails, then fix the
  code, then confirm the test passes.
- **Tests live with the code they test**: `Foo.jsx` ↔ `Foo.test.jsx` in
  the same directory. No `__tests__/` mirror of the entire src tree
  unless that's the existing convention.

### Naming

- Functions / methods / variables / props: `lowerCamelCase`.
- Classes / interfaces / types / components: `UpperCamelCase`.
- Module-level constants and enum members: `CONSTANT_CASE`.
- File names: per language convention — TS uses `snake_case`, JSX
  components named like the component (`UserCard.jsx`).
- Acronyms as words: `loadHttpUrl`, `customerId` — not `loadHTTPURL` /
  `customerID`.
- No abbreviations, no Hungarian, no `_` prefix/suffix on identifiers
  in TS.
- No `$` prefix outside framework requirements.

### Style (JS/TS)

- Single quotes, semicolons required, 2-space indent, 80-char column.
- Trailing comma when closing bracket on its own line.
- K&R braces, required for all `if`/`else`/`for`/`while`.
- `===` / `!==` always; `== null` exception for null-or-undefined check.
- `const` by default, `let` only when reassignment needed; never `var`.
- Function declarations for named functions; arrows for callbacks.
- `for…of` for arrays; `for…in` only on dicts with `hasOwnProperty`.

### Style (Python)

- 4-space indent, 80-char column.
- Per-file consistent quote style; docstrings use `"""`.
- 2 blank lines between top-level defs, 1 between methods.
- Always absolute imports; no `from x import *`.
- Type hints on public APIs; lowercase generics (`list[int]`).
- Google-style docstrings (`Args:` / `Returns:` / `Raises:` sections).
- Mutable default args forbidden (`def f(a=[])` is a bug).
- Bare `except:` forbidden; catch the narrowest class.

### Types (TS)

- Prefer inference over annotation for trivial initializers.
- `interface` for object shapes; `type` only for unions/primitives/tuples.
- `unknown` over `any`; if `any` necessary, suppress with comment.
- No `String`/`Boolean`/`Number`/`Object` wrapper types.
- Optional fields use `?`, not `|undefined` in type aliases.
- Type assertions: `x as Foo`, never `<Foo>x`.
- Avoid `!` non-null assertion without justification.

### Imports

- No default exports — always named.
- Side-effect imports only for libraries that need them.
- Type-only imports: `import type { Foo } from …` when only used in type
  position.
- No namespaces — use modules.

### Comments / docstrings

- Comments explain **why**, not **what**. If the code needs a "what"
  comment, simplify the code instead.
- JSDoc on all top-level exports; private only when non-obvious.
- TS JSDoc must NOT include type annotations (`@param {string}` etc.) —
  the TS keywords already convey it.
- Markdown allowed in JSDoc.
- Don't restate names/types in comments.

### Errors

- `throw new Error(...)` (or subclass) only — never strings.
- `catch (e: unknown)` in TS; assert via `instanceof Error`.
- Empty catch must have a comment explaining why.
- Bare `except:` forbidden in Python.

### Forbidden across all languages

- `eval` / `new Function(string)` (except code loaders).
- `debugger;` / `console.log` in production code.
- Modifying built-in prototypes.
- Mutable default arguments.
- Wildcard imports (`from x import *`, `import * as`).
- TC39 stage <4 features.

---

## Refactoring discipline (the 9-step pattern)

When extracting a component or module from a god-file:

1. **Survey the target**: read the inline code, identify boundaries,
   list all dependencies (state, callbacks, context, module constants).
2. **Write strict isolated unit tests** in a sibling `*.test.{jsx,py}`
   file, importing from the not-yet-existing target file. Cover every
   meaningful prop / arg / branch / edge case.
3. **Confirm tests fail** with file-not-found — that's the correct
   "red" state for the extraction.
4. **Add 1–3 integration regression tests** in the parent's test file
   exercising the about-to-be-extracted UI/behavior through the live
   parent.
5. **Confirm regression tests pass against current code** — establishes
   the baseline.
6. **Create the new component file** with the extracted code.
7. **Run isolated tests** — confirm pass.
8. **Remove the inline copy from the parent**, add the import, replace
   inline JSX with the new component invocation.
9. **Run the full suite** — confirm green. Commit.

If the file you're extracting depends on something that's also inline
in the god-file (e.g., a 1,600-line `<WordCard>` that the wrapper needs
to import) — STOP. Either extract that dependency first, or pivot to a
different target. Never use render-props or import-circularity hacks
to work around blocking inline-dependency.

---

## Commit-message format

Conventional Commits subject + structured body:

```
type(scope): imperative summary under 70 chars

Body paragraph in present tense, third person. Explains what changed
and WHY. Links to issue/CL/decision if any. Notes acknowledged
trade-offs.

Behavior: what the user-visible behavior change is (or "no behavior
change — pure relocation" for refactors).

Tests: count of tests added/changed; e.g. "+15 strict unit + 3
regression. Full suite: 138 → 156 (+18). All green."

Numbers (refactors): god-file lines before/after, lint warnings
before/after, anything else measurable.

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `perf`,
`security`, `build`, `ci`. Scope is optional but useful: `(phase4-w7b)`,
`(auth)`, `(security)`.

First-line rules from Google eng-practices:
- Imperative ("Add", not "Adds" or "Adding").
- Complete sentence written as an order.
- No issue numbers in the subject (put them in the body).
- No Phabricator-style `[area]` tag pileup in the subject.

---

## PR description format (Meta/Google quality)

Every PR opened by `/pr` follows this template (also at
[templates/PR_BODY.md](templates/PR_BODY.md)):

```markdown
## Summary

1–3 bullets. What changed and why. Stand-alone — readable without the
diff.

## Test plan

Required (Phabricator convention; reviewer must verify the change works).
Concrete:
- `npm test` → 156/156 pass
- New: `src/components/Foo.test.jsx` (10 strict tests covering …)
- Manual smoke on http://localhost:3000 → screenshot below

## Behavior

What user-visible behavior changes (or: "no behavior change — pure
refactor / relocation").

## Numbers (when refactor)

| Metric | Before | After |
|---|---|---|
| God-file lines | 9,237 | 9,144 |
| Tests | 138 | 156 |
| Lint warnings | 34 | 34 |

## Screenshots

(For UI changes — screenshot or screen recording. Required for any
visual change per Google reviewer norm.)

## Migration / breaking changes

(If any. Note rollback plan if risky.)

## Reviewer focus

The 2–3 files most worth a careful read; anything unusual to call out.

## Checklist

- [x] Tests added in same PR as production code
- [x] Lint + format + typecheck + full suite all green
- [x] No drive-by changes / unrelated fixes
- [x] Commit messages follow Conventional Commits
- [x] Doc updates included if user-facing behavior changed
```

---

## PR scope rules

From Google eng-practices ([small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html)):

- **~100 lines: usually fine. ~1000 lines: usually too large.**
- Spread matters: 200 lines in 1 file is fine; 200 lines across 50
  files is not.
- One self-contained change per PR — one slice of a feature, not the
  whole feature.
- "Too small" almost never happens. When in doubt, smaller.

**Never bundle:**

- Refactoring + feature change. (Tiny renames inside a feature PR are OK.)
- Reformatting + logic change.
- Multiple independent features.
- Unrelated drive-by fixes.
- Schema + the code that consumes it.

**Splitting strategies:**

- Stacked PRs (write PR #2 on top of #1 while #1 is in review).
- Test-first PR (characterization tests landing before the refactor).
- Vertical slice (full-stack thin slice for one feature).
- By layer (model → service → API → client).

---

## Anti-patterns this plugin actively REFUSES

These come from the author's prior round of "automated code improvement"
tooling that produced more harm than help. The model should push back
when asked to do any of these:

1. **`npm audit fix --force`** — can introduce major-version bumps that
   break the app. Use plain `npm audit fix` (semver-compatible only)
   and review the diff.
2. **Auto-commit CI workflows** that push fixes back to the branch.
   Auto-fixes belong in PRs you review, not in `git push origin main`
   from a GitHub Action.
3. **`jscodeshift` codemods** on a codebase without a real test net.
   Mechanical refactors silently break things; the test net must come
   first.
4. **"Swap React for Preact for performance"** in a working app — sold
   as a one-liner, actually a multi-week migration with rendering
   regression risk.
5. **Fake or wrong package names**: `@snyk/cli` (real name is `snyk`),
   `npm install semgrep` (semgrep is a Python tool, not npm),
   `npm-audit` (not a real package), Facebook's `codemod` (unmaintained
   since ~2019).
6. **`babylon-inspector`** (the real package is `@babylonjs/inspector`).
7. **Hardcoded fallback secrets** in source for production code:
   `const JWT_SECRET = process.env.JWT_SECRET || 'change-in-production'`
   means anyone reading the repo can forge tokens. Refuse to start in
   production without the env var.
8. **"Tests pass" as evidence of correctness without strict assertions**:
   `queryAllByText(/x/).length > 0` passes even if the UI is wrong; the
   test caught nothing. Push back on permissive assertions.

When the user (or another agent) suggests one of these, the model should
explain why it's refusing and propose the better path.
