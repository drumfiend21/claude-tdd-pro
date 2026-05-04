---
name: phase-0-snapshot
description: Use ONLY when the user explicitly invokes /snapshot or asks in clear terms to "establish a Phase 0 baseline" / "snapshot before refactoring" / "tag the current state before cleanup." Do NOT auto-trigger on casual mentions of code being messy — confirm with the user first. This skill writes 3 files and creates a git tag, so explicit consent matters. Establishes the safety net BEFORE any change.
disable-model-invocation: true
---

# Phase 0: Snapshot

You are about to clean up a real codebase that wasn't built TDD-first.
The discipline below makes recovery from any future mistake possible.

## When to use this

Trigger on:
- First session in a project that lacks a CLAUDE.md
- User says "I want to clean this up before [showing/deploying/etc.]"
- User asks to "refactor this whole thing"
- User describes the codebase as messy / accreted / vibe-coded

## What Phase 0 produces

After Phase 0, the codebase has:

1. **A git tag** marking the pre-remediation state (`pre-remediation-YYYY-MM-DD`).
2. **A top-level README.md** explaining the project layout, ports,
   run commands, and current status.
3. **A top-level CLAUDE.md** for AI assistants — architecture brief,
   "do not touch" zones, known landmines, current phase status.
4. **A REMEDIATION.md** punch list — every known bug, every planned
   phase of cleanup, with checkboxes.

These files are the asset. Even if the user never refactors anything,
the snapshot + docs are independently valuable.

## Step-by-step

### 1. Survey the codebase

Use the existing tools to understand:
- Top-level layout (one project? monorepo?)
- Tech stack (per `package.json` / `pyproject.toml`)
- Git state (branches, untagged commits, uncommitted changes)
- Existing docs (READMEs in subdirs?)
- Existing tests (how many? what framework? running?)
- Lint setup (any?)
- Hot spots (god-files >500 lines? files with TODO/FIXME density?)

Spend ~10% of time on the survey before writing anything.

### 2. Capture the snapshot tag

If there are uncommitted changes:
- Show the user `git status` + `git diff --stat`.
- ASK whether to commit them as a snapshot or stash them.
- If commit:
  - **MANDATORY**: run the secret-scan helper before any `git add`:
    ```bash
    bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/secret-scan.sh"
    ```
    Exit 2 means a secret-bearing filename or secret-shaped content
    is in the staged set. STOP. Surface the output to the user. Do
    not proceed until either:
      - the offending file is moved out of git's view, OR
      - the offending content is removed/redacted, OR
      - the user explicitly overrides with full awareness (and you
        document the override in the commit message).
  - Stage individually (`git add <file>` per file from the changes
    list); never `git add -A` blindly. Re-run secret-scan after staging.
- If stash: stash with a descriptive message.

Then:
```bash
git tag -a pre-remediation-$(date +%Y-%m-%d) -m "Snapshot before remediation work begins"
```

For multi-repo workspaces (sub-projects with their own `.git`), tag
each sub-repo separately.

### 3. Write the top-level README.md

Cover:
- One-paragraph "what this project is."
- Repository layout (if multi-project).
- Architecture summary in one paragraph + an ASCII diagram if helpful.
- Quick start: install + run commands.
- Environment variables required.
- Status (e.g., "currently mid-remediation; see REMEDIATION.md").
- Attribution if applicable.

Keep it short. Detail goes in subdir READMEs.

### 4. Write the top-level CLAUDE.md

This is the file every future Claude session reads first. Cover:
- What the project IS (one paragraph).
- Architecture in one table (path → stack → port → role).
- Any **two-database design / state machines / pipelines** that aren't
  obvious from the code. E.g., "we have read-only db.sqlite and
  read/write user.db; never mix."
- Auth / security model.
- The largest god-files (with line counts) and a note that they're
  being decomposed (which phase).
- Read-only / "don't touch" zones (e.g., generated code, asset
  pipelines).
- When to use Claude Code vs Copilot for which tasks.
- Code style notes (until the linter takes over).
- **Known landmines** — a bullet list of bugs/footguns you discovered
  during the survey, with file pointers.

End with: "When in doubt, ask. Default to small, reviewable diffs."

### 5. Write REMEDIATION.md

A live punch list, organized by phase:

```markdown
# REMEDIATION.md

Live checklist for the cleanup of <project>. Pre-remediation snapshot
tagged as `pre-remediation-YYYY-MM-DD`.

## Phase 0 — Snapshot, inventory, salvage *(in progress)*

- [x] Tag pre-remediation
- [x] Top-level README.md
- [x] Top-level CLAUDE.md
- [x] Top-level REMEDIATION.md
- [ ] (other Phase 0 items as applicable)

## Phase 1 — Guardrails *(not started)*

- [ ] ESLint flat config
- [ ] Prettier
- [ ] Husky + lint-staged pre-commit
- [ ] TypeScript checkJs (no rename)
- [ ] CI workflow (lint + test)

## Phase 2 — Characterization tests *(not started)*

- [ ] Test framework set up (vitest / pytest / node:test)
- [ ] Coverage of critical paths
- [ ] Integration regression tests

## Phase 3 — Targeted bug fixes *(not started)*

| # | Bug | Location |
|---|---|---|
| 1 | <discovered during survey> | <file:line> |

## Phase 4 — Decompose god-files *(not started)*

| Wave | Target | Lines | Coupling |
|---|---|---|---|

## Phase 5 — Polish + CI *(not started)*

- [ ] Per-project READMEs
- [ ] .env.example
- [ ] Security review
- [ ] v1.0.0 tag
```

Pre-fill the bug list and the wave list with what you discovered
during the survey. The user refines from there.

### 6. Commit the docs

```bash
git add README.md CLAUDE.md REMEDIATION.md
git commit -m "docs(phase0): snapshot + remediation plan

Phase 0 baseline before remediation work. Tagged pre-remediation-YYYY-MM-DD.
README + CLAUDE.md + REMEDIATION.md established for the cleanup process.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 7. Report back to the user

Summarize what you put in place, what's in REMEDIATION.md as the
proposed next steps, and ask which phase to tackle next. Default
suggestion: Phase 1 (guardrails) — it's low-risk, high-value, and
unblocks everything else.

## What to refuse

- **"Just start refactoring; we don't need the docs"** — push back.
  The docs are 30 minutes of work and prevent hours of debugging
  later when something goes wrong. If the user insists, do at least
  the tag and the REMEDIATION.md.
- **"Skip the snapshot tag"** — refuse. The tag is one git command.
  Without it, recovering from a bad refactor means manual diff
  archaeology.
- **"Force-push to clean up history first"** — refuse, especially if
  the repo is shared. History rewrites belong in a separate, deliberate
  step (Phase 5 security if `.env` was tracked) — never as a Phase 0
  drive-by.
