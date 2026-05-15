#!/usr/bin/env bash
# bundle-budget.sh — R-3 substrate stub (per §16 R-3 + §2.2 detector
# contract). Checks per-route first-load bundle size against the
# configured budget_kb (g-react-008 options).
#
# Per §2.2 detector contract: supports --json, --paths, --dry-run,
# --help, --options. Findings to stderr; exit 1 on budget overage.
#
# Usage:
#   bundle-budget.sh --json --paths "dist/routes/*.js" [--options '{"budget_kb":250,"per_route":true}']

set -uo pipefail

JSON=0
PATHS=""
OPTIONS='{"budget_kb":250}'
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: bundle-budget.sh --json --paths <glob> [--options <json>] [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "bundle-budget: dry-run; would walk $PATHS" >&2
  exit 0
fi

BUDGET_KB=$(OPTIONS="$OPTIONS" node -e 'try{const o=JSON.parse(process.env.OPTIONS||"{}");process.stdout.write(String(o.budget_kb||250))}catch(e){process.stdout.write("250")}' 2>/dev/null)
[[ -z "$BUDGET_KB" ]] && BUDGET_KB=250

# Portable glob expansion (macOS bash 3.2 lacks globstar).
EXPAND_BASE=""
EXPAND_PATTERN=""
EXPAND_RECURSIVE=0
case "$PATHS" in
  *"/**"*)
    EXPAND_BASE="${PATHS%%/\*\*/*}"
    [[ "$EXPAND_BASE" == "$PATHS" ]] && EXPAND_BASE="${PATHS%/\*\*}"
    EXPAND_PATTERN="${PATHS##*/}"
    [[ "$EXPAND_PATTERN" == "**" ]] && EXPAND_PATTERN="*"
    EXPAND_RECURSIVE=1
    ;;
  */*)
    EXPAND_BASE="${PATHS%/*}"
    EXPAND_PATTERN="${PATHS##*/}"
    ;;
  *)
    EXPAND_BASE="."
    EXPAND_PATTERN="$PATHS"
    ;;
esac

[[ -d "$EXPAND_BASE" ]] || exit 0

if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  FIND_DEPTH_FLAGS=""
else
  FIND_DEPTH_FLAGS="-maxdepth 1"
fi

EXIT_FILE=$(mktemp 2>/dev/null || echo "/tmp/bundle-budget-exit.$$")
echo 0 > "$EXIT_FILE"

find "$EXPAND_BASE" $FIND_DEPTH_FLAGS -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 wc -c 2>/dev/null \
  | awk -v budget="$BUDGET_KB" -v json="$JSON" -v exitfile="$EXIT_FILE" '
    {
      if (NF < 2) next
      if ($NF == "total") next
      bytes = $1
      file = $2
      for (i = 3; i <= NF; i++) file = file " " $i
      kb = int(bytes / 1024)
      if (kb > budget) {
        if (json == "1") {
          printf "{\"severity\":\"error\",\"rule_id\":\"react/bundle-size-budget\",\"file\":\"%s\",\"line\":0,\"finding\":\"route bundle %dKB exceeded budget %dKB\",\"suggested_fix\":\"split the route or move heavy dependencies behind dynamic import\"}\n", file, kb, budget > "/dev/stderr"
        } else {
          printf "bundle-budget: %s: %dKB exceeded budget %dKB\n", file, kb, budget > "/dev/stderr"
        }
        system("echo 1 > " exitfile)
      }
    }
  '

EXIT=$(cat "$EXIT_FILE")
rm -f "$EXIT_FILE"
exit "$EXIT"
