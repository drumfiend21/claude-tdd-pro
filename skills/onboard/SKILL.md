---
name: onboard
description: Use when the user explicitly invokes /onboard or asks to "give me a tour of this codebase" / "I'm new here, where do I start?" / "summarize this project for me." Performs a structured codebase tour, infers conventions from the existing files, and proposes a CLAUDE.md (or updates an existing one) so subsequent sessions have working context.
disable-model-invocation: true
---

# Onboard

You are giving a new contributor (human or future-Claude session) a
structured tour of an unfamiliar codebase. The output is both a
tour-narrative and an artifact (CLAUDE.md) future sessions can read.

## Process

### 1. Survey the layout

```bash
# Top-level shape
ls -la
# Detect monorepo / multi-project
find . -name "package.json" -not -path "*/node_modules/*" | head -20
find . -name "pyproject.toml" -not -path "*/.venv/*" | head -10
find . -name "Cargo.toml" -not -path "*/target/*" | head
find . -name "go.mod" | head
# Existing docs
ls README* CLAUDE.md AGENTS.md CONVENTIONS.md adr/ 2>/dev/null
```

### 2. Identify the stack

Per project (or per sub-project in a monorepo):
- Language(s) and version (from `engines` / `python_requires` / etc.)
- Framework (React, Express, FastAPI, Rails, etc.)
- Test runner
- Lint/format tools
- Build system

### 3. Find the "story shape"

What does this code DO at a one-paragraph level? Read:
- The top of the main README.
- The 2-3 most recent merged PR descriptions (`git log --oneline -20`).
- The largest source file (often a hint at where complexity lives).

### 4. Detect conventions

Without writing anything yet, infer:
- Naming conventions in use (camelCase / snake_case).
- Test file location convention (sibling vs `__tests__/` mirror).
- Error-handling style (exceptions / Result-types / nulls).
- Comment style (sparse / heavy JSDoc / docstrings).
- Anti-patterns the codebase already avoids or doesn't.

### 5. Surface what's missing

- Is there a `CLAUDE.md`? If not, propose one.
- Is there a `CONVENTIONS.md`? If not, suggest scaffolding from the
  plugin's template.
- Is there a `REMEDIATION.md`? If not, propose surveying for known
  bugs / hot files.
- Is the lint/test setup detectable? If not, suggest `/init-guardrails`.

### 6. Write the tour

Show the user a structured tour:

```markdown
# Codebase tour: <project name>

## What this is

[One paragraph from the survey.]

## Layout

[Tree-style; just the meaningful directories.]

## Stack

| Layer | Tech |
|---|---|
| Frontend | ... |
| Backend | ... |
| Database | ... |
| Tests | ... |

## How to run

[The 3-5 commands a new contributor needs.]

## Where the complexity lives

The 2-3 files / modules new contributors should read first. Any
known fragile zones.

## Conventions in use

[Short list inferred from grep + sample reading.]

## What's missing (suggested next steps)

- [ ] CLAUDE.md (would help future Claude sessions)
- [ ] CONVENTIONS.md (suggested scaffold via /sync-rules later)
- [ ] CI workflow
- [ ] REMEDIATION.md (if known bugs)
```

### 7. Offer to commit the artifact

If the user wants the tour persisted, save as `CLAUDE.md` (or
`CLAUDE.md` + `docs/codebase-tour.md` if a CLAUDE.md exists). Do NOT
overwrite an existing CLAUDE.md without asking.

## Constraints

- **Read-only survey**. Do not edit, install, or build during onboard.
- **One pass**. If the user asks "tell me more about X," that's a
  follow-up question, not another full tour.
- **Don't fabricate**. If you can't tell what a directory is for from
  reading, say "(unclear from contents — ask the team)".
- **Time-box**: 5-10 file reads should be enough. Reading every file
  is the wrong shape.
