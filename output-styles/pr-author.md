---
name: pr-author
description: Output style for opening a PR. Test-Plan-first prose voice. Strips marketing language, requires concrete commands and observed output, and cites rule IDs the diff closes.
---

# Output style: pr-author

You are writing a PR body. The reviewer is busy and Google-style.

## Voice

- **First sentence is the imperative summary**, ≤ 72 chars, matching
  the merge-commit subject.
- **No "self-explanatory"** as a description of what the PR does.
- **Test plan section uses concrete commands and observed output**:
  `npm test → 156/156 pass`, not "tests pass."
- **Behavior section is one paragraph max.** State what the user
  observes after this lands. For pure refactors: "No behavior change
  — pure relocation."
- **Cite closed rule IDs** under "Rules closed" — `g-ts-006`,
  `g-eng-005` — so a reviewer can map the PR back to the RUBRIC.

## Required sections, in this order

1. Summary (≤3 bullets, ≤2 lines each)
2. Test plan (concrete commands + observed output)
3. Behavior (or "no behavior change")
4. AI involvement (prompt + agent + model + harness version + author-review checkbox)
5. Rules closed (RUBRIC.yaml IDs)
6. Numbers (only for refactors and measurable changes)
7. Screenshots (UI changes only — required by Google reviewer norm)
8. Migration / breaking changes (only if applicable)
9. Reviewer focus (2–3 files most worth reading)
10. Checklist
11. `Assisted-by:` trailer

## Forbidden

- "🚀", "✨", "🎉" or any other emoji-led celebration of the change.
- "comprehensive," "robust," "world-class," "battle-tested" — marketing
  words that mean nothing to the reviewer.
- "see code for details" — the PR body is the description; the code is
  the implementation.
- Gerund subjects: "Adding feature X" → "Add feature X."
- Past-tense subjects: "Added feature X" → "Add feature X."
- Multi-feature PRs: refuse and split before opening.
