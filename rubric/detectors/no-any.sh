#!/usr/bin/env bash
# no-any.sh — T-3 substrate stub. Detects explicit `any` annotations
# in TypeScript files; respects `// allow-any: <reason>` comment
# affordance (g-ts-001 + g-ts-002 acceptance gate); honors
# max_per_file option to fail when over the cap.
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.
# Plus --options '{"max_per_file":N, "allow_with_comment_pattern":"..."}'.

set -uo pipefail

JSON=0
PATHS=""
OPTIONS='{}'
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: no-any.sh --json --paths <glob> [--options <json>] [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "no-any: dry-run; would walk $PATHS" >&2
  exit 0
fi

MAX_PER_FILE=$(OPTIONS="$OPTIONS" node -e 'try{const o=JSON.parse(process.env.OPTIONS||"{}");process.stdout.write(String(o.max_per_file||999999))}catch(e){process.stdout.write("999999")}' 2>/dev/null)

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
  FIND_DEPTH=""
else
  FIND_DEPTH="-maxdepth 1"
fi

EXIT=0
# Pre-filter: only files containing `any` need inspection.
CANDIDATES=$(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" -print0 2>/dev/null \
  | xargs -0 grep -lE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b|//[[:space:]]*allow-any:' 2>/dev/null)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  ALLOW_COUNT=$(grep -cE '^[[:space:]]*//[[:space:]]*allow-any:' "$f" 2>/dev/null || echo 0)
  ANY_COUNT=$(grep -cE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b' "$f" 2>/dev/null || echo 0)
  ALLOW_COUNT=$(echo "$ALLOW_COUNT" | tr -d ' \n')
  ANY_COUNT=$(echo "$ANY_COUNT" | tr -d ' \n')
  # Allow-any covers naked any (one-for-one).
  UNCOVERED=$(( ANY_COUNT - ALLOW_COUNT ))
  if [[ "$UNCOVERED" -gt 0 ]]; then
    while IFS=':' read -r ln content; do
      [[ -z "$content" ]] && continue
      if [[ "$JSON" -eq 1 ]]; then
        echo '{"severity":"error","rule_id":"types/no-any","file":"'"$f"'","line":'"$ln"',"finding":"no-any: any annotation without // allow-any: comment (google-tsguide §5.2)","suggested_fix":"// allow-any: <reason> on the line above"}' >&2
      else
        echo "no-any: $f:$ln any without allow-any: comment" >&2
      fi
      EXIT=1
    done < <(grep -nE ':[[:space:]]*any\b|<any>|as[[:space:]]+any\b' "$f" 2>/dev/null | head -1)
  fi
  # max_per_file: even with allow-any comments, too many is a code-smell.
  if [[ "$ALLOW_COUNT" -gt "$MAX_PER_FILE" ]]; then
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"warn","rule_id":"types/no-any","file":"'"$f"'","line":1,"finding":"no-any: '"$ALLOW_COUNT"' allow-any comments exceeded max_per_file '"$MAX_PER_FILE"'","suggested_fix":"reduce any usage or split the file"}' >&2
    else
      echo "no-any: $f: max_per_file ($MAX_PER_FILE) exceeded ($ALLOW_COUNT)" >&2
    fi
    EXIT=1
  fi
done <<< "$CANDIDATES"

exit "$EXIT"
