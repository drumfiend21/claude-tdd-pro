---
name: drift-detection
description: Post-commit scan for code-side bypass patterns (inline `rubric: ignore` comments, `--no-verify` commits, repeated bypasses) and cross-reference to the E-5 inline-suppression log. Use after a commit lands, or on demand to audit a codebase's bypass posture.
---

# Drift detection — code-side bypass scanner (F-4)

Architecture §3 F-4: "Drift-detection skill: post-commit scan for
`// rubric: ignore`, `--no-verify`, repeated bypass; tracks E-5 inline
suppressions."

## What it scans

- **Inline-comment bypass** — any source file containing the comment
  `// rubric: ignore` (case-insensitive, EOL or anywhere on a line).
  Repeated occurrences in a single file are counted; the count crosses
  an operator-set `--repeated-bypass-threshold` to escalate the finding.
- **`--no-verify` commit bypass** — git log scan for commits whose
  messages signal pre-commit hooks were skipped. In `--post-commit`
  mode the scan is limited to HEAD; otherwise the whole reachable log
  is scanned.
- **E-5 inline suppression tracking** — reads
  `rubric/suppressions/<rule-id>.jsonl` (the per-rule E-5 suppression
  log emitted by `rubric/detectors/inline-suppression.sh`) and surfaces
  per-rule suppression counts in the same report.

## Output

One JSON object per line to `--out <file>` (JSONL — stream-parseable).
Each line carries `type`, `path` (or `commit`), and `count`; escalated
findings include `severity:"escalated"`.

## Dry-run

`--dry-run` computes the same findings but does not write the report
file. The stderr summary includes `dry_run=true` for traceability.

## Exit codes

- `0` — clean scan (no bypasses, or `--dry-run` regardless of findings).
- `2` — bypasses found in the scanned scope (gates `/pr` and `/feature`
  in the W-2 / W-8 push-timing decision).
