---
name: fix-bug
description: Fix a bug using the bug-as-failing-test pattern. Test captures broken behavior first; fix follows; the test that would have caught the bug ships with the fix.
---

The user is reporting a bug. Bug description: $ARGUMENTS

Load the `bug-fix-discipline` skill. The fix never lands without the
test that would have caught it.

Steps:

1. **Reproduce** — get exact failing input, exact wrong output, expected
   output. If unclear, ask for precise repro before any code.
2. **Write a failing test** that asserts the EXPECTED behavior.
3. **Run it** — confirm it fails for the RIGHT reason (the bug, not
   a typo).
4. **Fix the code** — minimum change.
5. **Run the test** — confirm it passes.
6. **Run the full suite** — confirm nothing else broke.
7. **Commit** with a structured message including a clear Root Cause
   paragraph.

Do not refactor while fixing. One concern per commit.
