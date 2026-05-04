---
name: extract-component
description: Extract a component / module from a god-file using the strict 9-step test-first refactor pattern.
---

The user wants to extract code from one location into a new, focused
file. Target: $ARGUMENTS

Load the `test-first-extract` skill and follow the 9-step pattern
exactly:

1. Survey the target (props, state, callbacks, dependencies).
2. Write strict isolated unit tests in the sibling test file.
3. Confirm tests fail with file-not-found.
4. Add 1–3 integration regression tests in the parent's test file.
5. Confirm regression tests pass against current code.
6. Create the target file.
7. Run isolated tests — confirm pass.
8. Remove inline copy from parent + add import.
9. Run the full suite — confirm green; commit.

If the target depends on something inline that's also large/untested,
STOP and tell the user — extract that dependency first or pivot.
