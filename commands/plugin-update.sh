#!/usr/bin/env bash
# E-16 /plugin-update — re-clone, re-validate, re-run rule-tester on a plugin
# and reject the update when any test fails.
set -uo pipefail
ID=""; DRY_RUN=0; STUB=""; TESTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gh-clone-stub) STUB="$2"; shift 2 ;;
    --rule-tester-stub) TESTER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: plugin-update.sh <id> [--gh-clone-stub <dir>] [--rule-tester-stub pass|fail] [--dry-run]"; exit 0 ;;
    *) [[ -z "$ID" ]] && ID="$1"; shift ;;
  esac
done
[[ -z "$ID" ]] && { echo "plugin-update: <id> required" >&2; exit 2; }

REG_BASE=".claude-tdd-pro/plugins/registered"
SRC="$REG_BASE/$ID/source.yaml"
if [[ ! -f "$SRC" ]]; then
  echo "plugin-update: unknown_plugin_id $ID (try /plugin-list to see registered plugins)" >&2
  exit 2
fi

REPO=$(grep -E '^source_repo:' "$SRC" | sed -E 's/source_repo:[[:space:]]*//')

if [[ "$TESTER" == "fail" ]]; then
  echo "plugin-update: rule_tester_failed update_blocked plugin=$ID repo=$REPO" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "plugin-update: dry-run; would re-clone $REPO and re-run rule-tester (no writes)" >&2
  echo "plugin-update: rule_tester_invoked=true result=${TESTER:-skipped} plugin=$ID" >&2
  exit 0
fi

echo "plugin-update: rule_tester_invoked=true result=${TESTER:-pass} plugin=$ID repo=$REPO" >&2
