#!/usr/bin/env bash
# /plugin-update — substrate stub. Implements only --help and --dry-run
# semantics until the full feature CL lands. Per O-2: every subject
# command supports global --dry-run mode (§2.14 dry-run subjects).
#
# Usage:
#   plugin-update.sh [--dry-run] ...

set -uo pipefail

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: plugin-update.sh [--dry-run] ..."; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "plugin-update: dry-run; would perform plugin-update actions (no writes)" >&2
  exit 0
fi

# Substrate stage: real implementation lands in a later CL.
echo "plugin-update: substrate stub; only --dry-run + --help implemented" >&2
exit 0
