# Meta-eval calibration history

Quarterly + on-major-release calibration runs against the two reference corpora
per architecture §16 O-6:

- `meta-eval/known-good/` — pinned Kubernetes minor as a git submodule;
  calibration floor: ≤5 P0 findings, ≥90% P1 absence.
- `meta-eval/known-bad/` — synthetic anti-pattern codebase;
  calibration floor: ≥1 finding per anti-pattern.

Each run appends a structured entry via `meta-eval/run.sh` of the form:

```
<iso-date> target=<known-good|known-bad> trigger=<quarterly|major-release[:tag]> <findings>
```

Operator workflow: `bash meta-eval/run.sh --target <name> --findings-stub <kvs>`.
