---
name: react-component-build
description: Use when scaffolding or modifying React components, especially under the React 19 + Server Components model. Drives a TDD red-green-refactor flow that pairs with the review-react-rsc and review-react-a11y subagents, the four R-3 detectors (a11y-axe, bundle-budget, rsc-boundary, exhaustive-deps), and the R-4 templates (vitest.react.config.ts, playwright.config.ts, size-limit.config.js). Cites at least three g-react-NNN rules so contributors can grep their way to authoritative source files.
budget_impact_estimate: per-component-build runs review-react-rsc + review-react-a11y once each (~2 sonnet calls; ~2k input tokens, ~600 output) plus 4 detector invocations (cost-free local bash). Total cost class fast.
paths: ["**/*.tsx", "**/*.jsx"]
---

# React Component Build (R-5)

You are scaffolding or modifying a React 19 component. The target may
be a server component, a client component, or a hybrid of both. This
skill drives a TDD-feature-build flow (`tdd-feature-build` skill in
this plugin) so the work is red-green-refactor, not write-then-pray.

## When to invoke

- A new component is being created from scratch.
- An existing component is being modified beyond a one-line tweak.
- A reviewer flagged an a11y, bundle-size, or RSC-boundary issue and
  the fix needs structured guidance.

## Authority chain

This skill defers to the canonical sources:

- **R-2 rules** define what is right and wrong for this codebase.
  At minimum, this work touches `g-react-001` (RSC boundary
  integrity), `g-react-002` (exhaustive-deps), `g-react-003`
  (a11y P1 violations). Components emitting non-trivial JS bundles
  also touch `g-react-008` (bundle-size budget per route).
- **R-3 detectors** verify the rules locally:
  `rubric/detectors/a11y-axe.sh`,
  `rubric/detectors/bundle-budget.sh`,
  `rubric/detectors/rsc-boundary.sh`,
  `rubric/detectors/exhaustive-deps.sh`.
- **R-1 subagents** review the output:
  `agents/review-react-rsc.md` (server/client boundary review,
  client-only-import-in-server detection, missing-Suspense), and
  `agents/review-react-a11y.md` (WCAG 2.2 success-criterion
  mapping).
- **R-4 templates** drop into the target project:
  `templates/vitest.react.config.ts`,
  `templates/playwright.config.ts`,
  `templates/size-limit.config.js`.
  Install via `skills/react-component-build/_install.sh --target <dir>`.

## TDD red-green-refactor flow

1. **Red.** Write the failing component test first. Use the
   `strict-component-tests` skill for assertion guidance — prefer
   `getByRole({ name })` over text matchers; check render counts
   when state-management correctness matters; assert against the
   semantic DOM, never `.foo` CSS classes.

2. **Green.** Implement the minimum component code that turns the
   test green. Resist adding the second feature in the same iteration.

3. **Detector pass.** Run the four detectors against the changed
   files (this happens automatically in the `lint-on-save` hook;
   run manually with `bash rubric/detectors/<name>.sh --paths
   "src/**/*.tsx"`).

4. **Subagent review.** Spawn `review-react-rsc` and
   `review-react-a11y` for any non-trivial change. Each emits
   findings in the §2.3 contract shape; address all P0 findings
   before merging.

5. **Refactor.** With tests green and detectors clean, refactor
   for clarity: extract, rename, simplify. Tests stay green.

## Patterns this skill enforces

### Suspense around async server components

Every async server component must be wrapped in a `<Suspense>`
boundary at a sensible UI seam. Missing Suspense cascades to the
nearest ancestor and produces a poor loading UX. Pair Suspense
with an Error Boundary at the same boundary — async failures need
a recovery path that is explicit, not a white screen.

### Server-only imports stay server-only

Files marked `"use client"` must not import from `node:*`, `fs`,
`path`, `crypto`, or any package marked `server-only`. The
`rsc-boundary.sh` detector enforces this; `review-react-rsc`
explains the fix.

### Bundle budget per route

First-load JS for each route must respect the configured
`budget_kb` (default 250KB; override per route in
`size-limit.config.js`). The `bundle-budget.sh` detector exits
non-zero when a route exceeds budget, so CI fails the build
before the regression ships.

## Example invocation

```bash
# 1. Drop templates into a new project
bash skills/react-component-build/_install.sh --target ./my-app

# 2. Red: write the test
$EDITOR my-app/src/components/Card.test.tsx

# 3. Green: write the component
$EDITOR my-app/src/components/Card.tsx

# 4. Run detectors locally (mirrors what CI runs)
bash rubric/detectors/rsc-boundary.sh --json --paths "my-app/src/**/*.tsx"
bash rubric/detectors/a11y-axe.sh --json --paths "my-app/src/**/*.tsx"
bash rubric/detectors/exhaustive-deps.sh --json --paths "my-app/src/**/*.tsx"
bash rubric/detectors/bundle-budget.sh --json --paths "my-app/dist/_next/static/chunks/pages/*.js"
```
