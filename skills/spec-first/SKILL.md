---
name: spec-first
description: Use when the user describes a non-trivial feature or system that should be specified in writing before any code is written. Pattern from Geoffrey Huntley's "Ralph" loop, OpenSpec, intent-driven.dev, and Kent Beck's "augmented coding" framing — specs+tests are the durable artifact, code is the disposable one. Produces a Markdown spec document that the user reviews; only after approval does any code get written (typically via tdd-feature-build or /feature).
---

# Spec-first

You are producing a written specification for a feature BEFORE any
code is written. The spec is the durable artifact; the code is
generated from it (and can be re-generated later if requirements
shift).

## When to use this

- Features with multiple user-facing scenarios.
- Anything that involves data shape decisions (schemas, API contracts).
- Features that span multiple files / layers.
- ANY feature where the user can't yet articulate "the test I'd write
  for this is ____."

## When NOT to use this

- One-line config tweaks.
- Obvious bug fixes (use `bug-fix-discipline`).
- Pure refactors (use `test-first-extract`).

## Process

### 1. Capture the intent

Ask the user to articulate, in their own words:
- WHAT outcome they want (user-visible behavior).
- WHO benefits (which user / role / consumer).
- WHY this exists (the problem it solves; why now).

Do NOT proceed if the answer is "I want X." Push for "users currently
can't Y, which forces them to Z; with this they can Y directly."

### 2. Survey relevant existing code

Read enough of the codebase to know:
- Where the feature integrates.
- What patterns already exist that this should follow.
- What constraints exist (existing schemas, contracts, conventions).

Surface this as "Context found in the codebase" in the spec.

### 3. Write the spec

Save to `${CLAUDE_PROJECT_DIR}/specs/<slug>.md` with this structure:

```markdown
# Spec: <one-line title>

Status: DRAFT | APPROVED | IMPLEMENTED | OBSOLETE
Author: <user>
Date: <YYYY-MM-DD>
Related: [link to ADR, issue, PR]

## Context

What's the world before this change? Why is this needed now?

## Outcome

What's the world after this change? User-observable behavior, not
implementation.

## Scenarios

For each user-observable scenario, the format:

### Scenario: <name>

**Given**: precondition
**When**: action
**Then**: observable result

(Gherkin-style. Each scenario = one acceptance test.)

## Out of scope

Explicit list of what this spec does NOT cover. The "out of scope"
list prevents scope creep more than the "in scope" does.

## Data shape

Any new schemas, API contracts, persistence formats. Inline if small;
link out if large.

## Decisions

Decisions made during spec design that the reader should know about
(library picks, pattern choices, alternatives considered+rejected).
For non-trivial decisions, link to or stub an ADR.

## Risks / unknowns

What could go wrong. What we don't yet know. What we'll do if a risk
materializes.

## Test plan

The acceptance tests, listed by scenario. The implementation phase
(via `tdd-feature-build` or `tdd-driver`) writes these as failing
tests FIRST, then makes them pass.

## Implementation notes

Sequencing, suggested commits, file paths the implementation will
touch. The implementer may revise; this is an initial map.
```

### 4. Pause for approval

Show the user the spec. Ask explicitly:

> "Approve spec as written? Reply with one of:
> - `APPROVED` — implementation can begin
> - `REVISE: <reason>` — I'll update the spec
> - `ABORT` — drop this thread"

ANY OTHER REPLY = treat as revision request.

### 5. On APPROVED

- Set `Status: APPROVED` at the top of the spec.
- Commit the spec on its own (`docs(spec): <title>`).
- Suggest the next step: `/feature` or delegate to `tdd-driver`.

### 6. On REVISE

Update. Re-show. Re-ask.

### 7. On ABORT

Confirm cancellation. Do NOT delete the draft — the user can come
back to it.

## Constraints

- **Spec is short**: 200-500 words for most features. A 2,000-word
  spec is a smell — split into multiple smaller specs.
- **Spec is in markdown, in the repo**: not in a Google Doc or
  Notion page. Future engineers find it via `grep`.
- **No code in the spec**: data-shape examples are fine; code is
  not. The implementation phase produces code.
- **One spec per feature**: don't bundle. Splitting into multiple
  smaller specs is always an option.

## Why this matters

From Kent Beck's augmented coding framing: when AI is generating the
code, the SPEC is what survives across model revisions, prompt
rewrites, and refactors. The code can be regenerated; the spec is
the irreplaceable understanding. Treating the spec as the durable
artifact is what distinguishes "augmented coding" from "vibe coding."
