---
name: failure-domain-log
description: Use when a refusal fires, a bug recurs, the agent makes a mistake the user has to correct twice, or the user explicitly invokes /failure-log. Pattern from Geoffrey Huntley's "failure-domain documentation" + Stack Overflow's Mar 2026 guidance + Boris Cherny's recurring tip — when the model makes the same mistake twice, write it down so future sessions don't repeat it. Appends to the project's CLAUDE.md (or creates one if missing).
disable-model-invocation: true
---

# Failure-domain log

The model just made a mistake. Or the user just had to correct
something for the second time. Or a refusal fired and the underlying
issue was real. The lesson goes into the project's CLAUDE.md so the
next session doesn't repeat it.

## When this skill fires

- Explicit user invocation: "log this as a failure domain" /
  "/failure-log" / "add this to CLAUDE.md."
- Implicit: when the model has just been corrected for the second
  time on the same kind of issue in the same project (the model
  should self-trigger this).

## The discipline

Cursor's official best-practice guidance — converged across the
field by 2026 — is: **"only add a rule after the agent makes the
same mistake twice."** This skill operationalizes that.

## Process

### 1. Articulate the failure

What did the model do that was wrong? What's the specific shape of
the mistake (not just "it was wrong" but "it kept using
queryAllByText instead of getByRole")?

Write a 1-3 sentence root cause. The format:

> When working on X, the model tends to do Y. The correct approach
> is Z, because W.

### 2. Find the right place in CLAUDE.md

Look for an existing section that fits:
- "Known landmines" section?
- "Anti-patterns" section?
- "Conventions" section?
- A file-specific section ("the 5,792-line component")?

If a fitting section exists, append to it. If not, add a new section
under "Lessons learned (failure-domain log)".

### 3. Write the entry

```markdown
- **<short title>** (added YYYY-MM-DD)
  - When: <under what circumstances does this come up>
  - Mistake: <what the model tends to do>
  - Correct: <what to do instead>
  - Why: <the reason, in one sentence>
  - Source: <link to PR/commit/conversation if useful>
```

Example (real one from this project's history):

```markdown
- **Permissive test assertions** (added 2026-04-30)
  - When: writing tests for React components.
  - Mistake: using `screen.queryAllByText(/x/).length > 0` style
    assertions.
  - Correct: use `screen.getByRole('button', { name: /x/ })` with
    exact element queries.
  - Why: permissive assertions pass against broken UIs and provide
    no regression value. Pattern proven during Phase 4
    decomposition.
```

### 4. Commit

A failure-log entry should be a tiny standalone commit:

```
docs(failure-log): <short title>

Added a failure-domain entry to CLAUDE.md after the model repeated
the same mistake (specifics in the entry).

Assisted-by: Claude (claude-tdd-pro 0.3.0)
```

### 5. Re-read CLAUDE.md at session start

The whole point: future sessions read CLAUDE.md. Each entry is
worth maybe 50 tokens of context but saves potentially thousands
of tokens of correction back-and-forth.

## What to ALSO do (when applicable)

- If the failure suggests a missing skill / rule / hook: propose
  upstreaming to `claude-tdd-pro` (open an issue against the plugin
  repo).
- If the failure was caused by an anti-pattern that should be in
  CONVENTIONS.md (and re-synced to Cursor/Copilot/etc): add it
  there, then re-run `/sync-rules`.
- If the failure was security-shaped: add to the secret-scan
  patterns or expand the protected-branch list.

## Constraints

- **Don't expand the log unbounded**. CLAUDE.md should stay
  readable in a single page; if it grows to multiple pages, time
  to reorganize (move per-area lessons into per-area sub-files).
- **One entry per failure domain**, not per occurrence. Update an
  existing entry with a date suffix if the same domain comes up
  again with new nuance.
- **Stay specific**. Vague entries ("be careful with this file")
  don't help — concrete entries with the mistake / correct / why
  do.
