---
name: snapshot
description: Phase 0 setup. Tags pre-remediation, writes top-level README + CLAUDE.md + REMEDIATION.md based on a survey of the current codebase. Refuses to start any refactoring work without this snapshot in place.
---

The user wants to establish the Phase 0 baseline before any cleanup
work begins.

Load the `phase-0-snapshot` skill and follow it precisely:

1. **Survey** the codebase (~10% of time). Layout, stack, git state,
   existing docs, tests, lint, hot spots.
2. **Capture the snapshot tag** (`pre-remediation-YYYY-MM-DD`). For
   multi-repo workspaces, tag each sub-repo. Handle uncommitted
   changes carefully — never `git add -A` blindly; check for `.env`
   and secrets.
3. **Write top-level README.md** — what, layout, architecture, run
   commands, env vars, status.
4. **Write top-level CLAUDE.md** — architecture brief for AI
   assistants, do-not-touch zones, known landmines, when-to-use-which-
   tool guidance.
5. **Write REMEDIATION.md** — pre-filled punch list with bug findings
   from the survey and proposed phases.
6. **Commit** with `docs(phase0): snapshot + remediation plan`.
7. **Report** with the next-step suggestion (default: Phase 1
   `/init-guardrails`).

Refuse to start any refactor or feature work in the same session.
Phase 0 is foundation only.
