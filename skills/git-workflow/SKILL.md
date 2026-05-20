---
name: git-workflow
description: Git-workflow guidance — branch hygiene, branch-off triggers, divergence from main, merge-strategy selection, push timing. Per-profile threshold scaling (regulated halves defaults).
trigger: explicit
---

# Git-workflow skill

Per architecture §16 W-2. Recommends:
- **branch-hygiene**: detect stale branches with no commits in window.
- **branch-off**: when commit count exceeds threshold, recommend a new
  branch.
- **diverged-from-main**: warn when ahead+behind exceeds threshold.
- **merge-strategy**: squash for single-concern ≤3 commits; merge-commit
  for multi-concern; warn-against-rebase on shared branches.
- **push-timing**: warn when working tree has uncommitted changes.

Per-profile thresholds: `risk_tier: regulated` halves all defaults
(stricter discipline for higher-risk codebases).
