---
name: spec
description: TDD red-phase: writes failing tests from a feature description, grounded in the active profile's resolved standards source-folder set. Refuses to emit when grounding is absent (S-8 pattern) or when the active suite already covers the contract.
trigger: explicit
---

# /spec — write failing tests from a feature description

Per architecture §16 W-7. Inputs:
- Feature description (from W-1 ADR or operator argument).
- Active profile (per §2.5 `extends:`).
- Applicable compliance controls (per §2.9 `controls:`).
- §2.4 eval-spec schema.

## Refuses to emit when

- No standards source-folder grounds the description → exit non-zero with
  `declined reason=no_grounding_standard_available` (S-8 grounded-answer
  pattern).
- The active suite already covers the contract (same spec name in
  `evals/specs/`) → exit non-zero with `duplicate_coverage`.

## Emits

One `<feature-id>.test.<ext>` per testable contract, with header citing:
- `source_file:` (G phase rule file path)
- `docs_url:` (E-8 docs URL)

Each test is **red on commit** — CI surfaces the red state via
`evals/runner.sh --tests-dir <dir> --feature <id>`.

Commits carry a `Test-Driven-By: <feature-id>` trailer for traceability.
