#!/usr/bin/env bash
# /operator-namespace-init — substrate stub. Implements only --help and --dry-run
# semantics until the full feature CL lands. Per O-2: every subject
# command supports global --dry-run mode (§2.14 dry-run subjects).
#
# Usage:
#   operator-namespace-init.sh [--dry-run] ...

set -uo pipefail

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: operator-namespace-init.sh [--dry-run] ..."; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "operator-namespace-init: dry-run; would perform operator-namespace-init actions (no writes)" >&2
  exit 0
fi

# Substrate stage: real implementation lands in a later CL.
echo "operator-namespace-init: substrate stub; only --dry-run + --help implemented" >&2
exit 0
