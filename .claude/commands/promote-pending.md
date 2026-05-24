---
description: Promote a pending feature's specs to active with cl<N>- prefix. No probe — use only when you've just written new substrate and want to land it.
argument-hint: <phase> <feature-id> <descriptive-label> <cl-number>
---

Promote a pending feature's specs to the active suite.

Arguments: `<phase> <feature-id> <descriptive-label> <cl-number>`

Use this instead of [`/probe-feature`](probe-feature.md) when:
- You've just written brand-new substrate for the feature and the specs are KNOWN to need promotion (not a probe).
- You're in a substrate-write CL with the feature decomposed and tested manually.

Steps:

1. Verify the source folder exists: `evals/pending/<phase>/<feature-id>-<descriptive-label>/`.
2. Copy each `*.json` to `evals/specs/cl<cl-number>-<feature-id>-<base>.json`.
3. Filter-run: `bash evals/runner.sh --filter "cl<cl-number>-<feature-id>-"`. Must be `10 passed, 0 failed`.
4. Remove the source folder: `rm -rf evals/pending/<phase>/<feature-id>-<descriptive-label>`.
5. Update the active count: `ls evals/specs/ | wc -l`. Note for the commit body.

This is Step 1.5 of the workflow loop (between writing substrate and Step 3 full-suite verify).

If the filter-run fails:
- Fix the substrate (most common — apply [tdd-pro-bash32-portability](../skills/tdd-pro-bash32-portability/SKILL.md)).
- Or fix the spec (if the spec invented a flag/behavior the substrate can't satisfy without violating §X) — disclose the spec patch in the commit body.
- Re-filter-run until clean.
- Do NOT proceed to full-suite until filter-run is green.
