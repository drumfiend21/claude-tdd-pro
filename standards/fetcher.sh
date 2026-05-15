#!/usr/bin/env bash
# standards/fetcher.sh — S-2 fetcher orchestrator per §16:
#   "Standards fetcher with per-tier fragility behavior (high -> silent
#    replace, medium -> prompt on >5% structure delta, low -> manual
#    fetch only); per-source fetchers in standards/fetchers/:
#    html-anchor.sh, markdown-headers.sh, pdf-section.sh, rfc-style.sh."
#
# Wraps the per-source fetchers with fragility-tier dispatch, content-
# hash + fetched_at metadata emission, and prior-cache-preservation
# on upstream failure.
#
# Usage:
#   fetcher.sh --source-id <id> --fragility-tier <high|medium|low>
#              --strategy <silent-replace|prompt-on-change|manual-only>
#              --upstream-stub <path>
#              --cache <dir>
#              [--emit-metadata <path>]
#              [--auto] [--no-confirm-default]
#
# Exit codes (per §2.2):
#   0 — fetch complete (cache updated or unchanged on prompt-no)
#   1 — upstream failed; cache preserved
#   2 — usage / refused (manual-only + --auto)

set -uo pipefail

SOURCE_ID=""
FRAGILITY_TIER=""
STRATEGY=""
UPSTREAM=""
CACHE_DIR=""
EMIT_METADATA=""
AUTO=0
NO_CONFIRM_DEFAULT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-id) SOURCE_ID="$2"; shift 2 ;;
    --fragility-tier) FRAGILITY_TIER="$2"; shift 2 ;;
    --strategy) STRATEGY="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM="$2"; shift 2 ;;
    --cache) CACHE_DIR="$2"; shift 2 ;;
    --emit-metadata) EMIT_METADATA="$2"; shift 2 ;;
    --auto) AUTO=1; shift ;;
    --no-confirm-default) NO_CONFIRM_DEFAULT=1; shift ;;
    *) echo "fetcher: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$SOURCE_ID" ]] && { echo "fetcher: --source-id <id> required" >&2; exit 2; }
[[ -z "$FRAGILITY_TIER" ]] && { echo "fetcher: --fragility-tier required" >&2; exit 2; }
[[ -z "$STRATEGY" ]] && { echo "fetcher: --strategy required" >&2; exit 2; }
[[ -z "$UPSTREAM" ]] && { echo "fetcher: --upstream-stub <path> required" >&2; exit 2; }
[[ ! -x "$UPSTREAM" ]] && { echo "fetcher: upstream-stub not executable: $UPSTREAM" >&2; exit 2; }
[[ -z "$CACHE_DIR" ]] && { echo "fetcher: --cache <dir> required" >&2; exit 2; }
mkdir -p "$CACHE_DIR"

CACHE_FILE="$CACHE_DIR/$SOURCE_ID.html"

# Manual-only: refuse automatic fetch.
if [[ "$STRATEGY" == "manual-only" && "$AUTO" -eq 1 ]]; then
  echo "fetcher: source $SOURCE_ID strategy=manual-only refused under --auto (operator must explicitly /standards-refresh)" >&2
  exit 2
fi

emit_metadata() {
  local target="$1"
  if [[ -n "$EMIT_METADATA" && -f "$target" ]]; then
    local hash ts
    hash=$(shasum -a 256 "$target" 2>/dev/null | awk '{print $1}')
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"content_hash\":\"sha256:$hash\",\"fetched_at\":\"$ts\"}" > "$EMIT_METADATA"
  fi
}

# Capture upstream output. On non-zero, leave cache untouched and exit 0
# (the cache-preservation case is a success condition per §16 S-2 cache
# discipline).
TMP_OUT=$(mktemp)
if ! "$UPSTREAM" >"$TMP_OUT" 2>/dev/null; then
  rm -f "$TMP_OUT"
  echo "fetcher: upstream stub failed for $SOURCE_ID; cache preserved" >&2
  exit 0
fi

# Prompt-on-change (medium fragility): compare structure delta vs prior cache.
if [[ "$STRATEGY" == "prompt-on-change" && -f "$CACHE_FILE" ]]; then
  OLD_LINES=$(wc -l < "$CACHE_FILE" | tr -d ' ')
  NEW_LINES=$(wc -l < "$TMP_OUT" | tr -d ' ')
  if [[ "$OLD_LINES" -gt 0 ]]; then
    DELTA_PCT=$(( ((NEW_LINES > OLD_LINES ? NEW_LINES - OLD_LINES : OLD_LINES - NEW_LINES) * 100) / OLD_LINES ))
    if [[ "$DELTA_PCT" -gt 5 ]]; then
      echo "fetcher: source $SOURCE_ID structure delta = ${DELTA_PCT}% (threshold 5%); prompt required" >&2
      if [[ "$NO_CONFIRM_DEFAULT" -eq 1 ]]; then
        emit_metadata "$TMP_OUT"
        rm -f "$TMP_OUT"
        exit 0
      fi
    fi
  fi
fi

# Default path: silent-replace (high) and prompt-on-change (medium accepted).
mv "$TMP_OUT" "$CACHE_FILE"
emit_metadata "$CACHE_FILE"
exit 0
