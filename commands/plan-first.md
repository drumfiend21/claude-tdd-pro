---
name: plan-first
description: Force Plan Mode for non-trivial work. Produce a written plan with intent / scope / files to touch / test strategy / risks BEFORE any code change. Universal pattern across Cursor, Claude Code, Aider — Boris Cherny calls it the default for any session of substance. Refuses to start coding until the user approves the plan.
disable-model-invocation: true
---

The user wants to plan a non-trivial change before any code is
written. This is Plan Mode discipline.

## Process

### 1. Restate the goal in your own words

One paragraph. What does the user want, in your reading? If you can't
restate it without paraphrasing back the prompt, ask 1-2 clarifying
questions FIRST.

### 2. Survey the relevant code

Use Read / Grep / Glob to identify:

- The files this change will touch (or create).
- The existing patterns in those files that this change must follow
  or deliberately break.
- Hidden dependencies (other callers, related tests, docs).

Surface a brief inventory: "This change will touch N files in directories X, Y, Z. It depends on the existing pattern in `<file:line>`."

### 3. Write the plan

Emit a structured plan, ~200-500 words depending on scope:

```markdown
## Plan: <one-line title>

### Intent
What outcome the user gets after this lands. User-visible behavior, not
implementation.

### Scope
What's in. What's out. The "out" list matters most — explicit non-goals
prevent scope creep.

### Files
| Path | Action | Why |
|---|---|---|
| `src/foo.ts` | modify | Add new method `bar()` |
| `src/foo.test.ts` | modify | Add tests for `bar()` |
| `src/baz.ts` | new | Helper for `bar()` |

### Test strategy
The cycles you'll run, in order. Apply the TDD pattern: red, green,
refactor per scenario. List the scenarios.

### Risks / unknowns
What could break that you don't yet know. What you'll do if a risk
materializes (revert / split / ask).

### Estimated commits
~N commits, structured as: [list, with subjects].

### Sequencing
Order of operations. If anything depends on something else landing
first, say so.
```

### 4. Pause and ask for approval

Show the plan. Ask the user EXACTLY:

> "Approve plan as written? Reply with one of:
> - `APPROVED` — proceed
> - `REVISE: <reason>` — I'll update the plan
> - `ABORT` — drop this thread"

ANY OTHER REPLY = treat as a revision request and re-engage.

### 5. On APPROVED

- Save the plan to `${CLAUDE_PROJECT_DIR}/.claude-tdd-pro/plans/<slug>.md`
  for record-keeping (next session can resume from here).
- Suggest the natural next command:
  - For TDD feature work: `/feature` or invoke `tdd-feature-build`
  - For refactor: `/extract-component`
  - For bug: `/fix-bug`
  - For autonomous multi-scenario build: delegate to `tdd-driver` agent

### 6. On REVISE

Read the user's reason. Update the plan. Re-show. Ask again.

### 7. On ABORT

Do nothing. Confirm cancellation.

## When to use this command

- Any change that touches 3+ files.
- Any change with non-obvious sequencing.
- Any architectural decision (new module boundary, new dep, schema
  change).
- ANY change that seems "easy" but the user is unsure about — the
  plan often surfaces that it's not as easy as assumed.

## When NOT to use this command

- Tiny fixes (single-file, ≤10 lines, behavior obvious from prompt).
- Spike / experiment / prototype work where the plan is "we don't
  know what we'll find."

## Constraints

- **No code changes during planning.** Read-only operations only
  (Read, Grep, Glob). Editing is not part of plan mode.
- **No assumptions left unstated.** If you decide between two
  approaches, say which you picked and why. The plan is also a
  decision record.
- **Plans are concise.** A 2,000-word plan is a failure mode — the
  user won't read it. Aim for 200-500 words. Anything longer should
  be split into multiple plans.
