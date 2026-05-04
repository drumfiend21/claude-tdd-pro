# PR body template

The exact format `/pr` produces. Combines Google's CL-description norms
(stand-alone summary, what + why) with Phabricator's required Test Plan
section.

The skill `pr-quality` references this file. Sections in this order.

---

```markdown
## Summary

- [Bullet 1: what changed]
- [Bullet 2: why it changed]
- [Bullet 3 (optional): notable trade-offs]

## Test plan

- `npm test` → NN/NN pass ✅
- `npm run lint` → 0 errors, M warnings (pre-existing)
- `npm run typecheck` → 0 errors
- `npm run build` → clean
- New tests: `path/to/Foo.test.jsx` (N strict tests covering [list])
- Manual verification: [if UI / behavior change, describe steps]

## Behavior

[What user-visible behavior changes. For refactors: explicitly say
"no behavior change — pure relocation/restructure."]

## Numbers

(For refactors and measurable changes only.)

| Metric | Before | After |
|---|---|---|
| God-file lines | 9,237 | 9,144 |
| Tests | 138 | 156 |
| Lint warnings | 34 | 34 |

## Screenshots

(Required for any UI change per Google reviewer norm.)

![before](path/to/before.png)
![after](path/to/after.png)

## Migration / breaking changes

(Only if applicable. If breaking: rollback plan goes here too.)

[None / Describe what callers must change.]

## Reviewer focus

The 2–3 files most worth a careful read:

- `src/path/Foo.jsx` — new component; check the prop contract
- `src/path/Bar.jsx` — parent integration; check the inline-JSX
  removal didn't drop any prop wiring

[Plus anything unusual to call out: security implications, perf
considerations, deviation from convention.]

## Checklist

- [x] Tests added in same PR as production code
- [x] Lint + format + typecheck + full suite all green
- [x] No drive-by changes / unrelated fixes
- [x] Commit messages follow Conventional Commits
- [x] Doc updates included if user-facing behavior changed
- [ ] Screenshots attached (if UI change)
- [ ] Migration notes (if breaking change)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Section-by-section guidance

### Summary

1–3 bullets. Stand-alone — a reviewer who never opens the diff should
understand what changed and why. No "see the code" or "self-explanatory"
— that's how PRs get bounced back.

### Test plan

REQUIRED — Phabricator convention. Concrete commands + observed output,
not "tested locally." A test plan of one line for a 500-line PR is a
red flag.

For pure refactors: "Existing tests pass; no behavior change intended"
is acceptable but minimal — better to also list which existing tests
specifically cover the touched code.

### Behavior

The single most useful section for the reviewer's mental model. If the
answer is genuinely "no behavior change," say so explicitly — don't
leave the reviewer wondering if you forgot to mention something.

### Numbers

Optional but powerful for refactors. Tables make the impact quantifiable
and let future-you measure improvement over time. Include in commit
messages too (consistency with the commit-message template).

### Screenshots

Google reviewers require demos for UI changes. If the diff touches
JSX/templates, ask the user for a screenshot before opening the PR.

### Migration / breaking

If you're breaking callers, describe what they need to do. If risky,
include a rollback plan: "To revert, `git revert <sha>` and redeploy."

### Reviewer focus

A genuine kindness to your reviewer — they don't have to figure out
which 2-3 files matter most. Points them at the high-leverage parts of
the diff and tells them what to look for.

### Checklist

Tick only what's actually true. Empty tick boxes are a signal you're
not done.
