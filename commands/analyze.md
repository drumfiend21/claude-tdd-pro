---
name: analyze
description: Cold-start audit of the current codebase against Google's published engineering standards (eng-practices, JS/TS style, Python style). Produces COMPLIANCE-REPORT.md (ranked findings with citations) and LANDMINES.md (high-risk files to refactor with care). Read-only — no edits.
disable-model-invocation: true
---

The user has pointed Claude at a repo and asked for an audit against
the Google-derived RUBRIC.yaml. This is the entry point for the
two-phase elevation flow: `/analyze` produces the report; `/remediate`
acts on it.

## What you do

1. **Mark the active flow** so the Stop hook knows greenfield gating
   is OFF for this session:
   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.claude-tdd-pro"
   echo "analyze" > "${CLAUDE_PROJECT_DIR}/.claude-tdd-pro/active-flow"
   ```
   (`/analyze` is read-only, so the Stop gate does not need to fire on it.)

2. **Detect the stack.** Identify language(s), framework, package
   manager, test runner, lint posture, type checker, CI provider.
   Use file probes (`package.json`, `pyproject.toml`, `tsconfig.json`,
   `requirements.txt`, `go.mod`, `Cargo.toml`, `.github/workflows/`).

3. **Run the rubric.** Execute:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh" --full --md \
     > "${CLAUDE_PROJECT_DIR}/.claude-tdd-pro/rubric-report.md"
   bash "${CLAUDE_PLUGIN_ROOT}/rubric/runner.sh" --full --json \
     > "${CLAUDE_PROJECT_DIR}/.claude-tdd-pro/rubric-report.json"
   ```
   The runner skips gracefully when toolchains aren't installed; that
   IS a finding (record it under "Toolchain gaps" in the report).

4. **For LLM-deferred rules** (`g-eng-001-design-belongs-here`,
   `g-eng-002-yagni`, `g-eng-006-no-bundled-refactor-and-feature`,
   `g-eng-007-no-reformat-with-logic`, `g-eng-008-document-public-changes`),
   delegate to the `review-google-style` and `review-verifier`
   subagents in parallel. Their findings extend the report.

5. **Compute the landmine map** — files that are high-churn, high-
   complexity, and low-test-coverage. Approximation:
   ```bash
   git -C "${CLAUDE_PROJECT_DIR}" log --since='1 year ago' --name-only --pretty=format: \
     | grep -v '^$' | sort | uniq -c | sort -rn | head -30
   ```
   Cross-reference with files that have NO matching `*.test.*` /
   `test_*.py` neighbor. The intersection is the landmine set.

6. **Emit two artifacts** at the project root:

   **`COMPLIANCE-REPORT.md`** — sections in this order:
   - Executive summary: scorecard `P0: N · P1: M · P2: K · skipped: S`
   - Stack detection (one paragraph)
   - Toolchain gaps (what couldn't be checked because tools weren't installed)
   - P0 findings (table: rule | file | line | citation | remediation skill)
   - P1 findings (same shape)
   - P2 findings (same shape)
   - LLM-deferred findings from `review-google-style` / `review-verifier`
   - Eng-practices observations: small-CL discipline, doc shape, etc.
   - Recommended remediation order (the input to `/remediate`)

   **`LANDMINES.md`** — section per landmine file:
   - File path
   - Churn (commits in past year)
   - Approximate LOC
   - Test coverage status (file-level, since detailed coverage
     requires running the suite)
   - Why it's risky (no tests / high complexity / both / many
     dependents)
   - Required: characterization tests in the same CL as any refactor

7. **Print the executive summary to chat.** One screen. Show the
   scorecard, the top 5 P0 findings, and one sentence: "Run
   `/remediate` to begin the elevation pass."

## What you do NOT do

- **Do not edit any source file.** This command is read-only.
- **Do not run `/init-guardrails`** automatically — that may install
  configs the user does not want yet. Recommend it in the report if
  the toolchain gaps section is large.
- **Do not produce a CLAUDE.md** automatically — `/onboard` handles
  that and is a separate decision.
- **Do not delete or overwrite** any existing `COMPLIANCE-REPORT.md`
  or `LANDMINES.md`. If they exist, append a dated section
  (`## Audit 2026-05-04`) instead.

## Output contract

The user gets:
1. The two artifacts written at project root.
2. A short chat summary with the scorecard and the next-step prompt.
3. Citations every time you reference a Google rule, formatted as
   `(g-ts-001, jsguide §naming)`.

Optional focus area: $ARGUMENTS — if given, scope the audit to that
path only and note the scope in the report header.
