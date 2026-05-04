---
name: adr-writer
description: Use when the user explicitly invokes /adr or asks to "record an architecture decision" / "write an ADR." Produces an MADR-format Architecture Decision Record. Pattern from adr.github.io and the AgDR (Agent Decision Record) extension at me2resh/agent-decision-record. Lightweight, in-repo, future-engineer-readable.
disable-model-invocation: true
---

# ADR writer

You are recording an Architecture Decision Record (ADR) — a
permanent, in-repo document of a decision made and why. ADRs are
how teams remember "why did we pick X" three years later.

## Output format (MADR)

Save to `${CLAUDE_PROJECT_DIR}/adr/NNNN-<slug>.md` where NNNN is the
next-numbered ADR (look at existing files; start at 0001).

```markdown
# NNNN. <Decision title — short, declarative>

Date: YYYY-MM-DD
Status: Proposed | Accepted | Deprecated | Superseded by [NNNN]

## Context and Problem Statement

What's the situation? What forces are at play? What problem are we
trying to solve? 2-4 sentences.

## Decision Drivers

- Driver 1 (constraint, requirement, or quality attribute)
- Driver 2
- ...

## Considered Options

- **Option A**: short description
- **Option B**: short description
- **Option C**: short description (often: "do nothing")

## Decision Outcome

Chosen option: **Option X**, because [reason].

### Consequences

- **Positive**: ...
- **Negative**: ...
- **Neutral**: ...

## Pros and Cons of the Options (optional, when nuance matters)

### Option A
- Pro: ...
- Con: ...

### Option B
- Pro: ...
- Con: ...

## More Information (optional)

- Links to related design docs, RFCs, prototypes.
- Reference to the spec this ADR supports (if any).
- Reference to the PR that implements it (added later).
```

## When to write an ADR

- Picking a library / framework that locks the codebase in.
- Choosing between architectural patterns (event-driven vs
  request-response, monorepo vs polyrepo, REST vs GraphQL).
- Database schema decisions that are hard to reverse.
- Authentication / authorization model.
- Anything where future-you would ask "why did we do X?"

## When NOT to write an ADR

- Code style choices (those go in CONVENTIONS.md).
- Bug fixes (those are commit messages).
- Feature additions following an existing pattern (those are PR
  descriptions).
- Tiny choices ("which date library" if it's reversible).

## Process

1. **Identify the decision**. What was actually chosen, vs the
   alternatives that were rejected?
2. **Survey existing ADRs** (`ls adr/*.md`). Number the new one
   sequentially. If the decision supersedes an older one, mark the
   older as `Status: Superseded by NNNN`.
3. **Write the draft**. Keep it under 1 page. The point is durable
   context, not exhaustive prose.
4. **Show the user**. Ask: APPROVED / REVISE / ABORT.
5. **On APPROVED**: commit on its own (`docs(adr): NNNN <title>`).
   Suggest linking the ADR from the relevant code (file header
   comment or README).

## Agent-Decision-Record (AgDR) variant

For decisions made BY an AI agent (library pick, pattern choice
during implementation), prefix the title with `[AgDR]` and add an
"AI involvement" section mirroring the PR template:

```markdown
## AI involvement

- **Prompt / task**: [what was asked]
- **Agent**: [tdd-driver, /feature, etc.]
- **Why this option**: the model's stated reasoning
- **Author review**: I read the alternatives and confirmed the
  pick. ✅
```

This makes AI-made architectural decisions traceable and reviewable
later, which is the modern (2026) governance norm.
