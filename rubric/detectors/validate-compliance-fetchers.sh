#!/usr/bin/env bash
# C-1 detector: every COMPLIANCE-URLS.yaml entry's plugin-internal
# fetcher field names a script that ships under compliance/fetchers/.
# Operator may omit fetcher for entries they don't sync; default
# catalog entries MUST declare a fetcher.
set -uo pipefail
CATALOG=""; FETCHERS_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog) CATALOG="$2"; shift 2 ;;
    --fetchers-dir) FETCHERS_DIR="$2"; shift 2 ;;
    -h|--help) echo "Usage: validate-compliance-fetchers.sh --catalog <yaml> --fetchers-dir <dir>" >&2; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CATALOG" || ! -f "$CATALOG" ]] && { echo "validate-compliance-fetchers: --catalog <yaml> required" >&2; exit 2; }
[[ -z "$FETCHERS_DIR" || ! -d "$FETCHERS_DIR" ]] && { echo "validate-compliance-fetchers: --fetchers-dir <dir> required" >&2; exit 2; }

# Pair each id with the next fetcher: line that follows it.
CURRENT_ID=""
FAIL=0
COUNT=0
while IFS= read -r line; do
  if [[ "$line" =~ ^-[[:space:]]+id:[[:space:]]+([a-zA-Z0-9._-]+) ]]; then
    CURRENT_ID="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]+fetcher:[[:space:]]+([A-Za-z0-9._/-]+) ]]; then
    fname="${BASH_REMATCH[1]}"
    if [[ ! -f "$FETCHERS_DIR/$fname" ]]; then
      echo "validate-compliance-fetchers: id=$CURRENT_ID fetcher=$fname missing under $FETCHERS_DIR" >&2
      FAIL=1
    fi
    COUNT=$((COUNT + 1))
  fi
done < "$CATALOG"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "validate-compliance-fetchers: ok fetchers=$COUNT fetchers_dir=$FETCHERS_DIR" >&2
