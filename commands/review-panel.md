---
name: review-panel
description: Run a specialist review panel against the current branch's diff. Six parallel subagents (correctness, security, performance, observability, dependency-impact, google-style) produce severity-tiered findings; review-verifier filters false positives by re-grounding each Critical/High against the actual code; the panel chair synthesizes into a single report with a verdict line. Pattern from HAMY's 9-agent setup, Qodo's 2026 review framework, and Anthropic's March 2026 Code Review (which raised review coverage from 16% → 54% by adding the verification pass).
disable-model-invocation: true
---

The user wants a specialist-panel review of the current branch.

## Process

### 1. Establish the diff under review

```bash
BASE=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main)
DIFF_STATS=$(git diff "$BASE...HEAD" --stat)
DIFF_FILES=$(git diff "$BASE...HEAD" --name-only | wc -l)
DIFF_LINES=$(git diff "$BASE...HEAD" --shortstat)
```

Show the user the scope. If the diff exceeds the size guidance from
`pr-quality` (>1000 LOC, >50 files), warn that a review panel on a
diff this size is itself a smell — but proceed if they want.

### 2. Dispatch all 6 specialist subagents in parallel

In ONE message, fire all of these via the Agent tool:

- `review-correctness` — does the code do what the change description says? edge cases? race conditions?
- `review-security` — auth, input validation, injection, secrets, deps with CVEs
- `review-performance` — algorithmic complexity, N+1 queries, bundle bloat, render churn
- `review-observability` — logs, metrics, traces; can we debug a prod incident from this?
- `review-deps` — dep changes (additions/removals/version bumps); license/maintenance risks
- `review-google-style` — Google JS/TS/Python style + eng-practices judgment rules (small CL, doc shape, naming intent) — every finding cites a RUBRIC.yaml rule ID

Each subagent receives:
- the diff (`git diff $BASE...HEAD` content)
- the change description (latest commit messages on the branch)
- a pointer to QUALITY-BAR.md and rubric/RUBRIC.yaml for the quality bar
- if `${CLAUDE_PROJECT_DIR}/.claude-tdd-pro/rubric-report.json` exists, a pointer to it so they don't duplicate findings the rubric-runner already caught

Each returns a structured report:

```
Verdict: PASS | NEEDS-ATTENTION | NEEDS-WORK
Critical: [list of issues — file:line — rule-id (if any)]
High:     [list]
Medium:   [list]
Low:      [list]
Notes:    [non-blocking observations / praise]
```

### 3. Verification pass (review-verifier)

After all 6 specialists return, fire `review-verifier` with the
aggregated Critical + High findings as input. The verifier re-grounds
each finding by reading the actual code and labels it CONFIRMED,
OUT-OF-DATE, MISATTRIBUTED, FALSE-POSITIVE, or MITIGATED-BY-SIBLING-CODE.

Drop FALSE-POSITIVE findings before chair synthesis. Re-route
OUT-OF-DATE findings (re-run the originating specialist on the latest
diff). Apply MISATTRIBUTED corrections (move to the right file:line).
Pass CONFIRMED + MITIGATED to the chair.

This pass is what separates a noisy review panel from a trusted one —
Anthropic's own internal Code Review went from 16% → 54% effective
coverage by adding it. ([Anthropic Code Review, March 9 2026](https://claude.com/blog/code-review))

### 4. Synthesize as panel chair

Combine all 5 specialist reports into ONE document the user can paste
into a PR or share with a human reviewer:

```markdown
# Review-panel report — <branch>

**Diff**: <files changed> files, +<add>/-<del> lines (vs main)

## Verdict: READY TO MERGE | NEEDS ATTENTION | NEEDS WORK

(`READY TO MERGE` only if all 5 specialists return PASS with no
Critical or High findings.)

## Required before merge (Critical + High)

- [ ] [Specialist] [issue summary] — <file:line>
- [ ] ...

## Recommended (Medium)

- [ ] ...

## Non-blocking notes (Low / Praise)

- ...

## Per-specialist verdicts

| Specialist | Verdict | Critical | High | Medium |
|---|---|---|---|---|
| Correctness | PASS | 0 | 0 | 2 |
| Security | NEEDS-ATTENTION | 0 | 1 | 0 |
| Performance | PASS | 0 | 0 | 1 |
| Observability | NEEDS-WORK | 1 | 0 | 0 |
| Dependencies | PASS | 0 | 0 | 0 |
| Google-style | NEEDS-ATTENTION | 0 | 2 | 1 |

## Verification pass

| Class | N |
|---|---|
| Confirmed | 3 |
| Out-of-date | 0 |
| Misattributed | 0 |
| False positive | 1 |
| Mitigated-by-sibling-code | 1 |
```

### 5. Surface to the user

Show the report. Suggest the natural next step:
- If READY TO MERGE: suggest `/pr` next
- If NEEDS ATTENTION: list the High items; ask which to address now vs ship later
- If NEEDS WORK: list the Critical items; refuse to suggest `/pr`
  until they're resolved

## Constraints

- **All 5 in parallel** — sequential review is slow. Fire all subagent
  delegations in one tool-call message.
- **Subagent reports are summarized, not pasted in full** — the chair
  extracts the verdict and the items, not the working notes. Keep the
  final report under 500 words for human reviewability.
- **Don't fix anything during review.** Reviewers find; the parent
  agent / user decide what to do. Mixing review and fix in one pass
  loses the reviewer's distance.
