# Regression Baseline — 2026-05-07

Captured before v1.9 architecture build begins. Every subsequent CL MUST keep this baseline green.

## Plugin substrate inventory (v0.3.0)

- **Branch**: `feature/version-two`
- **Last commit**: `fd41df4 chore: bump to v0.3.0 + 7 new eval specs + README/CHANGELOG refresh`
- **Rules in `rubric/RUBRIC.yaml`**: 32 (across 11 axes)
- **Detectors in `rubric/detectors/`**: 6 (`cl-description.sh`, `cl-size.sh`, `pyink-check.sh`, `refused-flags.sh`, `secret-scan.sh`, `tests-coupled.sh`)
- **Hooks in `hooks/scripts/`**: 5 (`lint-on-save.sh`, `secret-scan.sh`, `stop-rubric-gate.sh`, `tdd-guard.sh`, `verify-deps.sh`)
- **Eval specs in `evals/specs/`**: 12 (all passing as of this baseline)

## Rule count by axis

| Axis | Rule count |
|---|---|
| style | 8 |
| py-correctness | 5 |
| ts-correctness | 4 |
| cl-shape | 4 |
| security | 3 |
| naming | 2 |
| comments | 2 |
| tests | 1 |
| documentation | 1 |
| design | 1 |
| complexity | 1 |

## Eval suite result (regression baseline)

```
Running claude-tdd-pro evals...

  ✓ cl-size-blocks-large-diff
  ✓ cl-size-passes-small-diff
  ✓ refused-flags-blocks-skip-permissions
  ✓ rubric-runner-emits-valid-json
  ✓ secret-scan-blocks-aws-key
  ✓ secret-scan-blocks-env-filename
  ✓ secret-scan-blocks-github-pat
  ✓ secret-scan-blocks-private-key
  ✓ secret-scan-passes-clean-diff
  ✓ stop-gate-noop-without-active-flow
  ✓ tests-coupled-flags-source-without-test
  ✓ tests-coupled-passes-with-test

Results: 12 passed, 0 failed
```

## Existing eval-spec schema (v0.3 substrate)

Each spec is a JSON file with: `name`, `command`, `setup` (array of bash commands), `expect: { exit_code, stderr_contains, stderr_not_contains }`. Runner: `bash evals/runner.sh [filter] [-v]`.

## Existing rubric rule schema (v0.3 substrate)

Each rule has: `id`, `axis`, `severity` (P0|P1|P2), `source: { upstream, local }`, `detector: { kind, ref, args? }`, `remediation: { kind, ref }`, `languages` (array). Top-level: `version`, `rubric_version`, `default_threshold`.

## Migration strategy (v0.3 → v1.9)

The v1.9 architecture extends this schema with E-8 ESLint-parity metadata, G-phase source-folder pointers, S-phase provenance entries, and C-phase control mappings. **Migration must preserve the 12 existing eval specs passing.**

Specifically, the new schema (per §2.1) adds: `name`, `description`, `type`, `fixable`, `has_suggestions`, `deprecated`, `replaced_by`, `docs_url`, `requires_type_checking`, `recommended`, `options_schema`, `messages`, `version` (semver), `cost_estimate`, `false_positive_log`, `provenance` (array; replaces `source`), `controls` (array), `rule_state`, `rule_state_history`, `legal_review_status`, `source_file`, `source_namespace`.

Existing fields preserved: `id`, `severity`, `detector` (now a path), `remediation` (semantically preserved via different fields), `languages` (mapped to `applies_to`).

## Definition of "no regression"

A CL is regression-free if and only if `bash evals/runner.sh` exits with code 0 and reports `12 passed, 0 failed` (or higher count if the CL itself adds new specs that also pass).
