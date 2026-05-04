---
name: adr
description: Write an Architecture Decision Record (MADR format) in the project's adr/ directory. Loads adr-writer skill.
disable-model-invocation: true
---

The user is recording an architecture decision.

Decision (what was chosen): $ARGUMENTS

Load the `adr-writer` skill. Produce an MADR-format ADR in
`${CLAUDE_PROJECT_DIR}/adr/NNNN-<slug>.md`. After APPROVED, commit on
its own.
