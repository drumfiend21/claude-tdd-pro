---
name: pr
description: Generate a Meta/Google-quality PR description and open the PR. Runs all pre-flight checks (lint/format/typecheck/test/build), refuses if any fail, drafts the body using the QUALITY-BAR template, asks the user for confirmation before pushing, then opens via gh pr create.
---

The user wants to open a pull request for the current branch.

Load the `pr-quality` skill and follow it precisely.

## Pre-flight (refuse the PR if any fail)

Run each in order. ALL must pass before drafting:

```bash
git status                          # confirm we're on a feature branch, not main
git diff main...HEAD --stat         # check scope; flag if unexpectedly large
npm run lint                        # 0 errors required
npm run format:check                # must pass
npm run typecheck                   # 0 errors required (warnings tolerated)
npm test                            # 100% pass
npm run build                       # if applicable, must succeed
```

If any step fails — STOP. Tell the user what failed and offer to fix.
Do not draft a PR for code that won't pass review.

## Scope check

If the diff is >1000 LOC of non-generated changes OR touches >50 files
OR bundles refactor + feature → propose a split BEFORE drafting. Show
the user the suggested stack of PRs.

## Drafting the body

Use `${CLAUDE_PLUGIN_ROOT}/templates/PR_BODY.md` as the template.
Fill in:

- **Title**: Conventional Commits format (`type(scope): summary`).
  Imperative, under 70 chars. Derive from the most-significant commit
  on the branch since `main`.
- **Summary**: 1–3 bullets. What changed and why.
- **Test plan**: REQUIRED. Concrete commands + observed output.
  List new test files with counts.
- **Behavior**: what user-visible behavior changed (or "no behavior
  change — pure refactor").
- **Numbers**: markdown table for measurable changes (god-file lines,
  test count, lint warnings).
- **Screenshots**: required for UI changes. ASK the user to provide
  them before drafting if a UI change is in the diff.
- **Migration / breaking changes**: only if applicable.
- **Reviewer focus**: 2–3 files most worth careful review.
- **Checklist**: tick only what's actually true.

## Confirmation + push

1. Show the user the drafted PR body.
2. Ask: "Open this PR? (y/n)".
3. On yes:
   ```bash
   git push -u origin <branch>
   gh pr create --title "..." --body "$(cat /tmp/pr-body.md)"
   ```
4. Return the PR URL.

Never open the PR without explicit user confirmation.
