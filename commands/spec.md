---
name: spec
description: Write a Markdown specification for a non-trivial feature BEFORE any code. Loads the spec-first skill explicitly.
disable-model-invocation: true
---

The user wants to specify a feature in writing before implementation.

Feature description: $ARGUMENTS

Load the `spec-first` skill and follow it precisely. Produce a spec
in `${CLAUDE_PROJECT_DIR}/specs/<slug>.md`. After APPROVED, suggest
`/feature` or delegate to `tdd-driver` for implementation.
