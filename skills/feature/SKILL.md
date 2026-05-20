---
name: feature
description: TDD green-phase implementer. Reads failing tests written by W-7 + active profile standards source-folder set; generates the implementation; TDD-Guard blocks commit on red, regression, or scope drift. Emits per-commit token telemetry; logs feature_complete to W-3 state machine.
trigger: explicit
---

# /feature — implement to turn red tests green

Per architecture §16 W-8. Inputs:
- `--feature-id <id>` — names the failing tests to satisfy.
- Active profile (per §2.5 `extends:`).
- W-7-emitted tests under `evals/specs/` carrying matching `feature_id`.

## TDD-Guard contract

The `hooks/scripts/tdd-guard.sh` PreToolUse hook on commit refuses when:
1. Any test in the named feature scope is still red.
2. Implementation regressed a previously-green active spec.
3. Implementation touches paths outside the feature scope declared by W-7.

`--allow-red-test` operator bypass is logged to the C-4 merkle-chained
audit log per the live-freshness contract bypass pattern.

## Emits

- Per-commit token telemetry to `.claude-tdd-pro/feature-runs/<id>.json`
  with `{tokens_in, tokens_out, model, cost_usd}` for H-1/H-12 rollup.
- `feature_complete: true` + `feature_id` to W-3 workflow state.
