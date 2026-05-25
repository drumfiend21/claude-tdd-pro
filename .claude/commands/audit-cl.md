---
description: Walk through the per-CL pre-commit audit. Use BEFORE drafting the commit message. Outputs an audit findings block ready to drop into the commit body.
argument-hint: <cl-number-or-range>
---

Walk through the CL audit checklist and emit the findings block for the commit body.

Argument: `<cl-number-or-range>` — e.g. `cl214` or `cl220..236`.

For each feature in the CL (filter by `cl<N>-` prefix on `evals/specs/`):

1. **Architecture fidelity**: print the feature ID and the architecture section quote. Confirm the folder name literally appears in `docs/architecture-v1.9.md`.
   ```bash
   grep -nE "\*\*<feature-id>\*\*" docs/architecture-v1.9.md
   ```

2. **Spec count**: must be exactly 10 specs in active for this feature.
   ```bash
   ls evals/specs/ | grep -c "^cl<N>-<feature-id>-"
   ```

3. **Non-shallow check**: scan the spec NAMES for verb diversity. Reject if all 10 names share the same verb stem (e.g. `validates-*` × 10).
   ```bash
   ls evals/specs/cl<N>-<feature-id>-*.json | xargs -I{} basename {} .json | sed -E 's/^cl[0-9]+-[A-Z]+-[0-9.]+-//' | awk '{print $1}' | sort | uniq -c
   ```

4. **No opaque IDs in names**: confirm no spec name contains a bare `F-1`, `E-7`, `(§2.X)`, `(C-9)` pattern.
   ```bash
   ls evals/specs/cl<N>-* | grep -E '[A-Z]-[0-9]+|§|\(C-|\(P-|\(L-|\(W-|\(H-|\(E-|\(G-|\(O-|\(S-|\(F-' | grep -v 'cl<N>-' | head -5
   ```

5. **Test-affordance flags invented**: scan substrate files touched in this CL for `--<flag>` patterns. Cross-reference against the architecture text. List any flag that doesn't appear verbatim in the architecture — those go in the commit body's "Test-affordance flags invented" section.

6. **Public-API only**: scan spec commands for any private substrate path (e.g. `_internal/`, `_private/`). Reject if found.
   ```bash
   grep -l '_internal\|_private' evals/specs/cl<N>-*.json
   ```

7. **Pending-spec content fidelity** (only when this CL promotes pre-existing pending specs; v1.9.2 §25): confirm `audit-pending-spec-fidelity.sh` was run for every promoted feature and reported exit 0, OR list every resolution chosen (spec rewrite / architecture amendment / misfiled relocation) per drift mechanism #6.
   ```bash
   bash rubric/detectors/audit-pending-spec-fidelity.sh \
     --pending evals/pending/<phase>/<feature-id>-<label>/ \
     --arch docs/architecture-v1.9.md --section "<§X>"
   ```

8. **Full-suite still green**: confirm `bash evals/runner.sh` reports `<N> passed, 0 failed` where `<N>` matches `ls evals/specs/ | wc -l`.

## Output format

Emit an audit block ready to paste into the commit body:

```
Audit findings:
- Per-folder mapping: cl<N>-<F1> → §<X> <F1>; cl<M>-<F2> → §<Y> <F2>; ...
  Every promoted folder traces to an exact architecture feature ID.
- 10/10 specs per feature, <total> total.
- No opaque IDs in names: every spec name describes behavior.
- Test-affordance flags invented: <list, or "none new">.
- Full-suite: <count>/<count> passed.
```

If any audit step fails, DO NOT propose the commit. Fix the issue first (re-write the spec name, restart from Step 0 if the folder is mislabeled, etc.).

This is Step 2 of the workflow loop and runs BEFORE Step 4 (propose commit).
