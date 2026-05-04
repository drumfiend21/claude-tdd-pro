---
name: pr-quality
description: Use when the user explicitly invokes /pr or asks to "open a PR / pull request / merge request" or "ship this feature for review." Generates Meta/Google-quality PR descriptions following the format from QUALITY-BAR.md. Refuses PRs that violate scope rules. Side-effecting (pushes branch, opens PR via gh) — explicit invocation only.
disable-model-invocation: true
---

# PR Quality

You are creating a pull request that should be approve-on-first-pass at
a company like Meta or Google. The standards are non-negotiable.

## Pre-flight checks (refuse the PR if any fail)

Before drafting any description, verify:

1. **Tests in same PR as production code** — not "I'll add tests in
   a follow-up." If there's no test file added/changed touching the
   new behavior, refuse: ask the user to add tests first or run
   `tdd-feature-build` to do it now.
2. **Lint clean** — `npm run lint` (or equivalent) returns 0 errors.
   Warnings allowed if pre-existing in the codebase; new code must
   not introduce new warnings.
3. **Format clean** — `npm run format:check` (or equivalent) passes.
4. **Type check clean** — `npm run typecheck` (or equivalent) returns
   0 errors. Warnings tolerated if pre-existing.
5. **Full test suite green** — `npm test` (or equivalent) passes
   100%.
6. **Build clean** — `npm run build` (if applicable) succeeds.
7. **No drive-by changes** — `git diff main...HEAD --stat` should
   touch only files related to the stated change. Diffs to unrelated
   files → ask if they're intentional; if not, revert them or split
   into a separate PR.

If ANY of these fail → fix before opening the PR. Don't draft a
description for code that won't pass review anyway.

## Scope rules (from QUALITY-BAR.md)

- **~100 lines: usually fine. ~1000 lines: too large.** Spread matters.
- **One self-contained change.** Not "the whole feature" — one slice
  of it.
- **Never bundle**: refactor + feature, reformat + logic change,
  multiple independent features, schema + consumers.

If the diff is too large or bundles concerns → propose splitting
BEFORE drafting the description. Give the user the suggested split as
a stack of PRs.

## The PR description (use this exact format)

Open `${CLAUDE_PLUGIN_ROOT}/templates/PR_BODY.md` and fill it in.
Sections, in order:

### Title
Conventional Commits format: `type(scope): imperative summary`.
- Imperative: "Add", not "Adds" or "Adding".
- Under 70 chars total.
- No issue numbers in the title (put in body).

### Summary
1–3 bullets answering "what changed and why." Stand-alone — readable
without the diff.

### Test plan
**REQUIRED** (Phabricator convention). Concrete:
- Commands run + observed output (`npm test → 156/156 pass`).
- New tests added (file paths + count + what they cover).
- Manual verification steps if applicable.
- For UI: screenshot or screen recording.
- For pure refactor: "Existing tests pass; no behavior change intended."

A test plan of "Tested." or empty → reject. Phabricator wouldn't
let you submit; we don't either.

### Behavior
What user-visible behavior changes. For refactors: explicitly say "no
behavior change — pure relocation."

### Numbers (if refactor / measurable)
Markdown table: Metric | Before | After. God-file lines, test count,
lint warnings, bundle size, etc.

### Screenshots
Required for UI changes per Google reviewer norm. Markdown image
syntax. If the user hasn't taken screenshots yet, ASK before opening
the PR.

### Migration / breaking changes
If applicable. Include a rollback plan for risky changes.

### Reviewer focus
2–3 files most worth a careful read. Anything unusual to flag
(security implication, perf consideration, deviation from convention).

### Checklist
The standard checkboxes. Tick only what's actually true.

## Opening the PR

1. Push the branch: `git push -u origin <branch>`.
2. Show the user the drafted PR body and ask: "Open this PR? (y/n)".
3. On yes, run `gh pr create --title "..." --body "$(cat …)"` with
   the drafted content.
4. Return the PR URL.

Do NOT open the PR without explicit user confirmation. The user is the
author of record.

## What a Meta/Google reviewer will check (and you should self-review against)

From `docs/standards/google-eng-practices.md`:

- **Design**: does this belong here? does it integrate cleanly?
- **Functionality**: does it do what's intended? edge cases / races
  considered?
- **Complexity**: simplest possible? any over-engineering?
- **Tests**: present, in this PR, fail-when-broken, useful?
- **Naming**: clear, intent-conveying, not too long?
- **Comments**: explain WHY, not WHAT?
- **Style**: conforms to language style guide?
- **Consistency**: matches surrounding code where style guide is
  silent?
- **Documentation**: README/docs updated if user-facing changes?
- **Every line**: does each line in the diff make sense?

If you can't answer "yes" to all of these for the diff you're about
to submit — fix it before opening the PR.

## After opening

Tell the user the PR URL and the most likely reviewer feedback. Be
honest: if there's something you took a shortcut on, flag it
proactively — better the user knows than the reviewer finds it.
