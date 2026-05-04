---
name: feature
description: Build a feature using strict TDD. Loads the tdd-feature-build skill explicitly and proceeds.
---

The user is asking you to build a feature with strict TDD discipline.

**Feature description:** $ARGUMENTS

Load the `tdd-feature-build` skill and follow it precisely. Do not
write any production code until a failing test exists for it. Do not
commit anything until the full test suite is green and lint/format/
typecheck all pass.

If the description is ambiguous on behavior boundary, data shape, UI
surface, persistence, auth scope, or failure modes — ask 1–3
clarifying questions before starting.

When the feature is complete and ready for review, suggest the user
run `/pr` to open a Meta/Google-quality pull request.
