---
name: sync
description: Multi-machine git-backed sync of local TDD Pro state via the `tdd-pro-sync` branch. Use when operators run claude-tdd-pro on more than one machine and want their FAILURE-LOG, decisions, audit checkpoints, workflow state, operator-curated URL registries, operator/community trees, and paywalled attestations to follow them between hosts.
---

# Sync — multi-machine state replication (O-4)

Architecture §13 O-4: "Multi-machine git-backed sync `skills/sync/SKILL.md`:
`tdd-pro-sync` branch with FAILURE-LOG, decisions.jsonl, fp-log/, audit
checkpoints, workflow-state, STANDARDS-URLS.yaml, PR-SOURCES.yaml,
COMPLIANCE-URLS.yaml, `_operator/` tree, `_community/` plugins, all
attestations."

## Synced contents

The canonical contents are listed by `skills/sync/list-contents.sh`:

- `FAILURE-LOG` — repeated-mistake log (CLAUDE.md companion)
- `pr-corpus/decisions.jsonl` — L-13 conflict-surfacing log
- `standards/decisions.jsonl` — S-phase reconciliation log
- `fp-log/` — false-positive tracking per rule (F-4)
- `audit-checkpoints/` — O-5 signed checkpoint files (cross-ref C-4.6/C-4.7)
- `.claude-tdd-pro/workflow-state.json` — W-3 workflow state machine
- `STANDARDS-URLS.yaml`, `PR-SOURCES.yaml`, `COMPLIANCE-URLS.yaml` —
  the three operator-curated URL registries (S-14, L-17, C-13)
- `generated-code-quality-standards/_operator/` — operator namespace
  tree (G-8, §2.22 cascade)
- `generated-code-quality-standards/_community/` — installed
  community plugins (G-11)
- `attestations/` — all paywalled compliance attestations (C-19)

## Push

`skills/sync/push.sh --root <repo> [--dry-run]` writes the configured
contents to the `tdd-pro-sync` branch. `--dry-run` reports the planned
operation without mutating any ref. The destination branch name is
fixed by the architecture and is **not** operator-configurable.

## What sync does NOT carry

- Generated audit-pack tarballs (these are reproducible from inputs)
- The plugin source code itself (operator installs via `/plugin install`)
- `.claude-tdd-pro/rule-cache/` (per-machine cache; would invalidate on sync)
- Bootstrap seed corpus (`seed/`; ships with the plugin, not operator state)
