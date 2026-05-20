---
name: shared-learning
description: Opt-in anonymous aggregate false-positive / true-positive count emission for community calibration.
trigger: opt-in
opt_in: true
privacy: aggregate-only
---

# Anonymous Shared-Learning Skill

Aggregate FP / TP counts only. Operator-hashed identifier (sha256 of user
string), no IP collection, no per-rule detail. Disabled by default. The
operator must explicitly pass `--opt-in` (typically wired through a profile
`shared_learning.enabled=true` setting and a one-time consent dialog).

## Privacy posture

- `aggregate-only`: only summed FP/TP counts are emitted; per-rule keys are
  stripped before egress.
- `no_ip_collection=true`: the egress path does not record client IP,
  X-Forwarded-For, or any other network identifier.
- `hashed_id`: a stable but un-reversible sha256 of the operator's local
  user string is used to de-duplicate emissions without identifying them.

## Triggers

`opt-in` only — never fires automatically. The skill exits with
`opt_in_required` if invoked without `--opt-in`.
