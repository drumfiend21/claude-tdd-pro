#!/usr/bin/env bash
# O-4 multi-machine sync — canonical contents listing.
# Emits the architecture-defined set of files / directories that the
# `tdd-pro-sync` branch replicates between operator machines (§13 O-4).
set -uo pipefail

cat >&2 <<'CONTENTS'
sync: tdd-pro-sync branch synced contents:
  FAILURE-LOG
  pr-corpus/decisions.jsonl
  standards/decisions.jsonl
  fp-log/
  audit-checkpoints/
  .claude-tdd-pro/workflow-state.json
  STANDARDS-URLS.yaml
  PR-SOURCES.yaml
  COMPLIANCE-URLS.yaml
  generated-code-quality-standards/_operator/
  generated-code-quality-standards/_community/
  attestations/
CONTENTS
