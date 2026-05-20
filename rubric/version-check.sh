#!/usr/bin/env bash
# O-10 rubric semver checker. Validates RUBRIC.yaml version is semver,
# reports lock pin, and (with --enforce) blocks on lock/current mismatch.
set -uo pipefail
RUBRIC=""; LOCK=""; ENFORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rubric) RUBRIC="$2"; shift 2 ;;
    --lock) LOCK="$2"; shift 2 ;;
    --enforce) ENFORCE=1; shift ;;
    -h|--help) echo "Usage: version-check.sh [--rubric <yaml>] [--lock <json>] [--enforce]"; exit 0 ;;
    *) shift ;;
  esac
done

CURRENT=""
if [[ -n "$RUBRIC" && -f "$RUBRIC" ]]; then
  CURRENT=$(grep -E '^version:' "$RUBRIC" | head -1 | sed -E 's/version:[[:space:]]*//' | tr -d ' "')
  if ! [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "version-check: invalid_semver version=$CURRENT rubric=$RUBRIC (expected X.Y.Z)" >&2
    exit 2
  fi
  echo "version-check: current=$CURRENT rubric=$RUBRIC" >&2
fi

if [[ -n "$LOCK" && -f "$LOCK" ]]; then
  LOCKED=$(LOCK="$LOCK" node -e 'process.stdout.write(String((JSON.parse(require("fs").readFileSync(process.env.LOCK,"utf8")).rubric_version)||""))')
  echo "version-check: lock_rubric_version=$LOCKED lock=$LOCK" >&2
  if [[ "$ENFORCE" -eq 1 && -n "$CURRENT" && "$LOCKED" != "$CURRENT" ]]; then
    echo "version-check: lock_mismatch lock=$LOCKED current=$CURRENT (run rubric/lock.sh --init to refresh, or pin profiles to current)" >&2
    exit 2
  fi
fi
