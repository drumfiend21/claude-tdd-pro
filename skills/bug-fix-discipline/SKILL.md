---
name: bug-fix-discipline
description: Use when the user reports a BUG (existing behavior is wrong) — phrases like "X breaks when Y", "this used to work", "got an error/exception/500", "regression", "this is a bug". NOT for new features (use tdd-feature-build). Enforces bug-as-failing-test — capture the broken behavior FIRST, confirm red, fix, confirm green. The fix never lands without the test that would have caught it.
---

# Bug Fix Discipline

A bug is evidence the test net failed. Every bug fix must close that
gap by adding the test that would have caught it.

## The discipline (no exceptions)

1. **Reproduce the bug.** Get the exact failing input, the exact
   wrong output, and the expected output. If the user can't give you
   precise reproduction steps, ASK before writing any code.
2. **Write a failing test** that captures the broken behavior.
   - The test asserts the EXPECTED behavior.
   - It must fail against the current (buggy) code.
3. **Run the test. Confirm it fails for the RIGHT reason** (the bug,
   not a typo / missing import / fixture mismatch). Wrong reason → fix
   the test, re-run, get to the right red.
4. **Fix the bug.** Minimum code change. Don't refactor while you're
   in here.
5. **Run the test. Confirm it passes.**
6. **Run the full suite. Confirm nothing else broke.**
7. **Commit** with a structured message:
   ```
   fix(scope): one-line summary of what was wrong

   Root cause: <one paragraph on why the bug existed>

   Test: <test file + test name that would have caught this>

   Tests: +1 test covering the regression. Suite NN/NN green.

   Assisted-by: Claude (claude-tdd-pro 0.3.0)
   ```

## Why this matters

If you fix a bug without writing a test first:

- The bug can silently come back during a refactor; nothing will catch
  it.
- You can't prove the fix actually fixes the reported bug; the test
  might be testing the wrong thing.
- Over time the codebase grows test coverage only for happy paths and
  has no tests for the actual edge cases that broke users.

The bug-as-test pattern guarantees that every bug ever reported has a
test guarding it.

## Special case: capturing CURRENT (broken) behavior

Sometimes the bug is real but you can't fix it in this PR (architectural
reasons, deferred to a later phase). In that case:

1. Write a test that captures the CURRENT behavior, even though it's
   wrong.
2. Mark the test clearly: `// CURRENT BUG: bug #N. Phase 3 will flip
   this assertion when fixing.`
3. The test PASSES against current code (capturing the broken behavior
   for posterity).
4. When the actual fix happens later, the assertions in this test get
   flipped to the correct behavior — and the fix is the proof.

Example from prior session:

```js
// Phase 3 bug #2: malformed JSON in word_selections crashes the GET
// response. Capturing current behavior; Phase 3 will fix and flip
// to expect the row to be returned with translations: {}.
it('CURRENT BEHAVIOR (bug #2): malformed JSON crashes the GET endpoint', async () => {
  // ... seed a row with bad JSON ...
  const res = await request(app).get('/api/saved-translations/...');
  expect(res.status).toBe(500); // ← will flip to 200 in Phase 3
});
```

This is the technique that lets you triage bugs incrementally without
losing track of any of them.

## Refuse to skip the test

If the user says "just fix it, I don't have time for a test":

- Push back. The test is the SHORTEST path to confirming the fix
  actually fixes the reported bug. Adding a test takes 5 minutes;
  debugging the same bug recurring takes hours.
- If they insist after the push-back, write the test ANYWAY as part
  of the fix and explain in the commit message why.
- Do not ship the fix without the test.

## What to log in the commit

The Root cause section is critical. It's what future-you (or a
reviewer) will read to understand why the codebase had this gap. Be
specific:

- "AbortController was missing from the fetch call, so when the
  component unmounted mid-flight the response setState fired on an
  unmounted component."
- "JSON.parse on word_selections was bare; one row with corrupt
  JSON poisoned the entire list endpoint."
- "Date.parse() returns NaN on invalid input; the merge-list logic
  used `>=` against NaN which is always false, so newer entries were
  silently overwritten."

A good Root cause explanation prevents the same class of bug elsewhere.
