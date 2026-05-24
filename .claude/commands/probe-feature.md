---
description: Probe whether a pending feature passes against existing substrate. Promotes specs with cl<N>- prefix, filter-runs, and rolls back if any fail. Use when substrate may already satisfy a pending feature (common mid-project).
argument-hint: <phase> <feature-id> <descriptive-label> [cl-number]
---

Probe a pending feature for substrate-already-shipped promotion.

Arguments: `<phase> <feature-id> <descriptive-label> [cl-number]`
  - `<phase>` — phase folder under `evals/pending/` (e.g. `W`, `L`, `H`, `C`, `E`, `G`, `O`, `S`, `P`, `CC`)
  - `<feature-id>` — architecture feature ID (e.g. `W-2`, `L-8`, `H-1`, `C-9`, `CC-2-1`)
  - `<descriptive-label>` — folder suffix (e.g. `git-workflow`, `pr-corpus-learn`)
  - `[cl-number]` — optional; if omitted, derive from highest existing `cl<N>` prefix + 1.

Steps:

1. Find the source folder: `evals/pending/<phase>/<feature-id>-<descriptive-label>/`. Bail if not found.
2. Determine the CL number: if not provided, run `ls evals/specs/ | grep -oE '^cl[0-9]+' | sort -u | tail -1` and increment.
3. Stage probe specs: for each `*.json` in the source folder, copy to `evals/specs/cl<N>-<feature-id>-<base>.json`.
4. Filter-run: `bash evals/runner.sh --filter "cl<N>-<feature-id>-" 2>&1 | tail -5`.
5. If `0 failed`: promotion is clean. Remove the source folder (`rm -rf evals/pending/<phase>/<feature-id>-<descriptive-label>`). Report `cl<N> <feature-id> PASS`.
6. If any fail: ROLL BACK (`rm evals/specs/cl<N>-<feature-id>-*.json`). Report `cl<N> <feature-id> FAIL: <count>` and which specs failed. The feature needs new substrate — keep pending for a substrate-write CL.

After a successful probe, the active suite count goes up by 10 but no commit happens yet. Run several probes, then batch them per [tdd-pro-batch-cl](../skills/tdd-pro-batch-cl/SKILL.md).
