---
name: test-first-extract
description: Use when the user asks to EXTRACT or RELOCATE existing code into its own file, module, or component ("extract X", "split out Y", "pull Z into its own file", "decompose god-file"). NOT for net-new features (use tdd-feature-build) or behavior changes (use fix-bug). Enforces the 9-step extraction with isolated unit tests + integration regression tests as a two-tier safety net.
---

# Test-First Extraction

You are extracting code from one location into a new, focused file.
The risk is silent regression — props dropped, callbacks rewired wrong,
state coupling broken. The discipline below makes that risk catchable.

## Pre-flight

1. **Read `QUALITY-BAR.md`** for the strictness rules and refactor
   discipline.
2. **Identify the parent file** the code is being extracted FROM and
   the **target path** it's being extracted TO.
3. **Detect / create the test infrastructure** at the target path's
   sibling (`Foo.jsx` ↔ `Foo.test.jsx`). If the project uses a
   different convention (e.g. `__tests__/` mirror), match it.
4. **Read the integration regression test file** at the parent's level
   (or create one if absent). This is where you'll add the cross-cutting
   tests that catch wiring breaks.

## The 9-step extraction

### Step 1: Survey the target

Read the inline code being extracted. Build a complete inventory:

- **Props** the new component will receive (with types if known).
- **State** owned by the new component vs. owned by the parent.
- **Callbacks** the new component will fire upward.
- **Module-level dependencies** (constants, utility functions, other
  components, context). Will the new file import these, or will the
  parent pass them as props?
- **Side effects** (effects, refs, API calls). Where do they belong
  after extraction?

If anything in the inventory is itself inline in the parent (e.g., a
1,600-line component the wrapper depends on) — STOP. Either extract
that dependency first, or pivot to a different extraction. Never use
render-props or import-circularity hacks to work around blocking
inline dependencies.

### Step 2: Write strict isolated unit tests FIRST

Create `<Target>.test.{jsx,ts,py}` at the target path's sibling.
Import from the target file path (which doesn't exist yet — that's
intentional).

Cover EVERY meaningful prop / arg / branch / edge case from your survey:

- Default props → renders correctly?
- Each prop variation → behaves correctly?
- Each callback → fires with the right args?
- Each conditional branch → both sides covered?
- Edge cases: empty arrays, null/undefined, large inputs?

Apply the strictness rules from QUALITY-BAR.md:
- `getByRole` over `queryAllByText`.
- Exact counts where uniqueness is expected.
- jest-dom matchers (`toBeInTheDocument`, `toBeDisabled`,
  `toHaveAttribute`).
- `userEvent` over `fireEvent` for interactions.

### Step 3: Confirm tests fail with file-not-found

Run just the new test file. They MUST fail with file-not-found (or
import error). That's the correct "red" state.

If they pass somehow → you imported from the wrong path; fix.
If they fail for any other reason → fix the test, don't proceed.

### Step 4: Add 1–3 integration regression tests in the parent's test file

Open the parent's integration test file (e.g.,
`ScriptureEngineV2.regression.test.jsx`). Add tests that exercise the
about-to-be-extracted UI/behavior THROUGH the live parent.

These tests:
- Render the parent with the harness mocks.
- Assert observable behavior (text on screen, fetch URL fired,
  click → callback) — NOT implementation details.
- Will survive the move from inline JSX → child component without
  modification.

### Step 5: Confirm regression tests pass against current code

Run the integration tests. They MUST pass against the current (still-
inline) code. This establishes the baseline.

If they fail → your test is wrong; fix until green. The baseline must
be solid before you touch the code.

### Step 6: Create the target file with the extracted code

Now (and only now) create `<Target>.{jsx,ts,py}` and copy the inline
code into it, transformed into a function/class accepting the props
you defined in step 1.

Keep behavior IDENTICAL. This is a relocation, not an improvement
opportunity. Resist the urge to "clean up while you're here" — that
expands scope and undermines the test net.

### Step 7: Run isolated tests — confirm pass

Run just the new test file. All tests should pass. If any fail, the
extraction has a real bug — fix the implementation (not the test).

### Step 8: Remove inline copy from parent + add import

Open the parent. Remove the inline code. Add:
```js
import { Target } from './path/to/Target.jsx';
```
Replace the inline JSX with `<Target {...props} />`.

For React: pass props the parent owns; wire callbacks to parent's
state setters.

### Step 9: Run the FULL suite — confirm green; commit

Run every test in the project — unit + integration + regression. All
must pass.

If anything is red → revert the parent edit (step 8), debug, retry.

If green → commit using QUALITY-BAR.md commit format:
```
refactor(scope): extract <Target> from <Parent>

Process: tests-first (10 strict unit tests for the target + 2
regression tests in the parent suite); confirmed file-not-found
failure; created target; verified isolated 10/10; replaced inline
~N lines with <Target …>; full suite NN/NN green.

Behavior: no behavior change — pure relocation.

Numbers: parent file XXX → YYY lines (-N). Tests: AA → BB (+N).

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Common pitfalls

- **Skipping step 3 (confirm red)**: if you don't confirm the new tests
  fail with file-not-found, you might write tests that accidentally
  pass against some other code path. The red is the proof you're
  testing the right thing.
- **Skipping step 5 (confirm regression baseline)**: if you don't run
  the regression tests against the CURRENT code first, you don't know
  whether the test itself works. After extraction it could pass for
  the wrong reason.
- **Cleaning up during the move**: combine extraction with refactoring
  → you can't tell which change broke things if the suite goes red.
  Pure relocation first, refactor in a follow-up commit.
- **Render-prop / import-circularity hacks**: if the target depends on
  something also inline in the parent, extracting the wrapper is just
  papering over the problem. Extract the dependency first.

## Sub-extraction strategy for huge targets

If the "target" is a 1,000+ line block:

1. Identify SUB-boundaries within it (the next-smaller cohesive units).
2. Extract the smallest, most-self-contained sub-piece first.
3. Repeat until the parent block has shrunk to something reasonable.
4. Then extract the now-smaller block as a coherent component.

This is the "wave" pattern — each wave is its own commit, each commit
runs through the full 9 steps.
