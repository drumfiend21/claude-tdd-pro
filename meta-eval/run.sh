#!/usr/bin/env bash
# O-6 external meta-eval runner. Runs against known-good (≤5 P0, ≥90% P1 absence)
# or known-bad (≥1 finding per anti-pattern). Quarterly + major-release triggered.
set -uo pipefail
TARGET=""; FINDINGS=""; ANTI=""; HISTORY=""; NOW=""; DRY=0
TRIGGER="quarterly"; RELEASE_TAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --findings-stub) FINDINGS="$2"; shift 2 ;;
    --anti-patterns-stub) ANTI="$2"; shift 2 ;;
    --history) HISTORY="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --trigger) TRIGGER="$2"; shift 2 ;;
    --release-tag) RELEASE_TAG="$2"; shift 2 ;;
    -h|--help) echo "Usage: run.sh [--target known-good|known-bad] [--findings-stub k=v,...] [--anti-patterns-stub k=v,...] [--history <md>] [--now <iso>] [--trigger quarterly|major-release [--release-tag <tag>]] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$DRY" -eq 1 ]]; then
  echo "meta-eval: planned: known-good (≤5 P0, ≥0.90 P1 absence) invoked=false dry_run=true" >&2
  echo "meta-eval: planned: known-bad (≥1 finding per anti-pattern) invoked=false dry_run=true" >&2
  exit 0
fi

if [[ "$TRIGGER" == "major-release" ]]; then
  echo "meta-eval: trigger=major-release release_tag=$RELEASE_TAG at=$NOW" >&2
fi

# Parse k=v stubs into associative shell variables.
get_kv() {
  local s="$1" key="$2" pair val
  for pair in ${s//,/ }; do
    [[ "$pair" == "$key="* ]] && { echo "${pair#$key=}"; return; }
  done
  echo ""
}

if [[ "$TARGET" == "known-good" && -n "$FINDINGS" ]]; then
  P0=$(get_kv "$FINDINGS" "p0")
  P1ABS=$(get_kv "$FINDINGS" "p1_absence")
  if [[ -n "$P0" && "$P0" -gt 5 ]]; then
    echo "meta-eval: known-good calibration FAILED p0_count=$P0 p0_max=5 (architecture floor: ≤5 P0)" >&2
    exit 1
  fi
  if [[ -n "$P1ABS" ]]; then
    OK=$(P1ABS="$P1ABS" node -e 'process.stdout.write(parseFloat(process.env.P1ABS)>=0.90?"1":"0")')
    if [[ "$OK" != "1" ]]; then
      echo "meta-eval: known-good calibration FAILED p1_absence=$P1ABS p1_absence_min=0.90 (architecture floor: ≥90% P1 absence)" >&2
      exit 1
    fi
  fi
fi

if [[ "$TARGET" == "known-bad" && -n "$ANTI" ]]; then
  FAILED=0
  for pair in ${ANTI//,/ }; do
    name="${pair%%=*}"
    count="${pair#*=}"
    if [[ "$count" -lt 1 ]]; then
      echo "meta-eval: known-bad calibration FAILED anti_pattern=$name findings=$count (architecture floor: ≥1 finding per anti-pattern)" >&2
      FAILED=1
    fi
  done
  [[ "$FAILED" -eq 1 ]] && exit 1
fi

# Append history entry.
if [[ -n "$HISTORY" ]]; then
  mkdir -p "$(dirname "$HISTORY")"
  ENTRY="$NOW target=$TARGET trigger=$TRIGGER"
  [[ -n "$RELEASE_TAG" ]] && ENTRY="$ENTRY release_tag=$RELEASE_TAG"
  [[ -n "$FINDINGS" ]] && ENTRY="$ENTRY $FINDINGS"
  [[ -n "$ANTI" ]] && ENTRY="$ENTRY anti_patterns=$ANTI"
  echo "$ENTRY" >> "$HISTORY"
fi

echo "meta-eval: pass target=$TARGET trigger=$TRIGGER at=$NOW" >&2
