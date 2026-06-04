# Hotfix without AI — emergency procedure

Per the simulated Birgitta Böckeler / Patrick Kua review, the project
must have a documented path for an urgent fix that does **not**
depend on Claude / AI assistance. This is the procedure.

## When to invoke

- Production-blocking bug in the rubric runner, installer, or hooks.
- Security vulnerability in a fetcher or skill substrate.
- Architecture text correction that consumers depend on (false
  documentation can mislead downstream operators).

## Pre-requisites

The contributor must have:

- Read `docs/architecture-v1.9.md` for the affected scope.
- Read `CLAUDE.md`, especially the workflow loop and drift mechanisms.
- A working Bash 4+, Node 18+, Ruby 3+ toolchain.

No AI / Claude / Copilot / Codex / Cursor assistance is required or
expected during this procedure.

## Procedure

### 1. Identify the affected feature ID

Open `docs/architecture-v1.9.md`. Find the §X that owns the bug.
Note the feature ID (e.g., F-2) and the feature description verbatim.
Write it on paper or in a scratch file. You will quote it in your
commit.

### 2. Identify the affected substrate

Either:

- The feature description names a file path. Open that file.
- The feature has no explicit path. Search the repo:
  `grep -rln "F-2" rubric/ commands/ hooks/ skills/ | head -5`

### 3. Reproduce the bug

Write a minimal failing test in `evals/specs/cl<N>-<feat>-<desc>.json`:

```json
{
  "name": "<feat>: <one-sentence description of the bug>",
  "command": "<single-line bash command that exits non-zero when bug present>",
  "setup": [],
  "expect": {"exit_code": 0, "stderr_contains": ["<expected output when fixed>"]}
}
```

Run it: `bash evals/runner.sh --filter "cl<N>-<feat>-"`. Confirm the
spec fails. **This is your regression test.**

### 4. Fix the substrate

Edit the affected file. Make the minimum change that turns the
failing spec green. Do not refactor. Do not extract. Do not add
abstractions. Hotfix discipline: smallest possible diff.

### 5. Verify

Run the four fitness functions:

```bash
bash rubric/detectors/audit-substrate-completeness.sh
bash rubric/detectors/audit-cli-surface-fidelity.sh
bash rubric/detectors/audit-spec-depth.sh
# (the §25 fidelity gate is invoked automatically when promoting a
#  pending spec; skip if you're hotfix-writing directly to evals/specs/)
```

All must report `clean`. If any reports `dirty`, fix the regression
your hotfix introduced.

Then the full suite:

```bash
bash evals/runner.sh
```

Result line must read `Results: <N> passed, 0 failed`. No exceptions.

### 6. Commit

The commit message must include:

```
hotfix: <feat> <one-line summary>

Per docs/HOTFIX_WITHOUT_AI.md emergency procedure (no AI assistance).

Architecture extraction: <verbatim feature description from arch.md>
Affected substrate: <file path>
Regression test: evals/specs/cl<N>-<feat>-<desc>.json

Audit:
  - All four fitness functions clean
  - Full suite: <N> passed, 0 failed
  - No new files created beyond the regression test
  - Minimum-diff change in substrate

Reviewed-by: <secondary maintainer or self if solo emergency>
```

### 7. Push

```bash
git push origin main
```

If the project has a release pipeline, follow the release procedure
in `docs/RELEASE.md`. If not, the push itself is the release.

## What is forbidden during a hotfix

- Refactoring unrelated code.
- Adding abstractions or "fixing while we're in here."
- Changing the architecture document (that's a governance CL, not a
  hotfix).
- Updating the installer, CHANGELOG, or version numbers (those happen
  on the next normal CL).
- Bypassing any fitness function with `--force` or `EXEMPT.txt`.

## Why this exists

The session that generated most of this codebase was AI-assisted. If
the maintainer's AI access is interrupted (account issue, service
outage, regulatory restriction, model deprecation), the project must
remain maintainable. This procedure is the **proof that the
discipline carries the project**, not the assistant.

The primary maintainer rehearses this procedure quarterly against a
synthetic bug and records the wall-clock time in
`docs/hotfix-rehearsal-log.md`.

## See also

- `MAINTAINERS.md` — succession plan
- `CLAUDE.md` — full per-CL workflow (the version that allows AI
  assistance)
- `CONTRIBUTING.md` — non-emergency contribution path
