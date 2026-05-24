---
description: Run the full eval suite (bash evals/runner.sh) and report pass/fail count. Use as the final pre-commit gate.
---

Run the active eval suite from the repo root and report the result.

```bash
bash evals/runner.sh 2>&1 | tail -10
```

Expected output: `Results: <N> passed, 0 failed`.

If any fail:
1. Run again with the failing spec name filter: `bash evals/runner.sh --filter "<spec-base-name>"`
2. Look at the spec's `command` field in `evals/specs/<spec>.json` and reproduce manually.
3. Common failure modes: see [tdd-pro-bash32-portability](../skills/tdd-pro-bash32-portability/SKILL.md).
4. Do NOT mark the commit as ready until the suite is 100% green.

If you're inside an active CL: this is Step 3 of the workflow loop. After this passes, proceed to Step 4 (propose commit).
