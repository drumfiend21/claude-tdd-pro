#!/usr/bin/env bash
# standards/conditional-get.sh — S-21 conditional-GET fetcher layer +
# §2.29 conditional-GET freshness-economy contract (v1.12 §27).
#
# Per §2.29: each non-paywalled fetcher persists the upstream `etag` and
# `last_modified` response headers alongside `content_hash` in
# .claude-tdd-pro/standards-last-fetch/<id>.json and sends
# `If-None-Match` / `If-Modified-Since` on subsequent fetches. On
# `304 Not Modified`: update the freshness timestamp, increment the 304
# counter, and skip the downstream parse/diff/hash-compare pipeline. On
# `200`: run the full pipeline and refresh stored headers. H-12 records the
# per-source `304:200` ratio. Paywalled/HEAD-only sources are exempt.
# Conditional GET never advances `content_hash` or suppresses an S-5 diff
# when content actually changed.
#
# Per §27 S-21: extends the S-2 fetchers (html-anchor / markdown-headers /
# rfc-style) with the above. This script is the shared conditional-GET
# decision + header-store layer those fetchers call.
#
# The HTTP response is injected for hermetic testing (no live network): the
# fetcher caller supplies the simulated status + headers; in production the
# caller passes the real curl response.
#
# CLI:
#   --source-id <id>          (required)
#   --store-dir <dir>         header store dir
#                             (default .claude-tdd-pro/standards-last-fetch)
#   --simulate-status 200|304 injected response status (default: 304 when a
#                             stored validator exists, else 200)
#   --etag <val>             upstream etag on a 200
#   --last-modified <val>    upstream last_modified on a 200
#   --body-hash <hash>       content hash of the fetched body on a 200
#   --paywalled              source is HEAD-only — skip conditional GET
#   --now <iso>              freshness timestamp (default: current UTC)
#
# stderr report tokens:
#   conditional-get=skipped-paywalled
#   request_if_none_match=<etag|none>  request_if_modified_since=<lm>
#   fetch=cold-full
#   response=304-not-modified | response=200-ok
#   pipeline=skipped | pipeline=full
#   freshness_timestamp_updated=<iso>
#   content_changed=true|false   diff=triggered
#   ratio_304_200=<count_304>:<count_200>
#
# Exit: 0 success / 2 usage error.

set -uo pipefail

SOURCE_ID=""
STORE_DIR=""
SIM_STATUS=""
ETAG=""
LAST_MODIFIED=""
BODY_HASH=""
PAYWALLED=0
NOW=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source-id)       SOURCE_ID="${2-}";     shift 2 ;;
    --store-dir)       STORE_DIR="${2-}";     shift 2 ;;
    --simulate-status) SIM_STATUS="${2-}";    shift 2 ;;
    --etag)            ETAG="${2-}";          shift 2 ;;
    --last-modified)   LAST_MODIFIED="${2-}"; shift 2 ;;
    --body-hash)       BODY_HASH="${2-}";     shift 2 ;;
    --paywalled)       PAYWALLED=1;           shift ;;
    --now)             NOW="${2-}";           shift 2 ;;
    -h|--help)
      echo "Usage: conditional-get.sh --source-id <id> [--store-dir <dir>] [--simulate-status 200|304] [--etag <v>] [--last-modified <v>] [--body-hash <h>] [--paywalled] [--now <iso>]" >&2
      exit 0
      ;;
    *) echo "conditional-get: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE_ID" ]; then
  echo "conditional-get: --source-id is required" >&2
  exit 2
fi

STORE="$STORE_DIR"
if [ -z "$STORE" ]; then STORE=".claude-tdd-pro/standards-last-fetch"; fi
mkdir -p "$STORE"
F="$STORE/$SOURCE_ID.json"
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

# Paywalled / HEAD-only: conditional GET is moot (HEAD already cheap).
if [ "$PAYWALLED" -eq 1 ]; then
  echo "conditional-get=skipped-paywalled" >&2
  exit 0
fi

# Load stored validators (tolerant of a missing or malformed store file).
stored=$(F="$F" ruby -rjson -e '
  f = ENV["F"]
  h = {}
  if File.exist?(f)
    begin
      h = JSON.parse(File.read(f))
    rescue
      h = {}
    end
    h = {} unless h.is_a?(Hash)
  end
  printf("%s\t%s\t%s\t%s\t%s\n", h["etag"]||"", h["last_modified"]||"", h["content_hash"]||"", h["count_200"]||0, h["count_304"]||0)
')
stored_etag=$(printf '%s' "$stored" | cut -f1)
stored_lm=$(printf '%s'   "$stored" | cut -f2)
stored_hash=$(printf '%s' "$stored" | cut -f3)
count_200=$(printf '%s'   "$stored" | cut -f4)
count_304=$(printf '%s'   "$stored" | cut -f5)

# Build the conditional request from stored validators (§2.29).
if [ -n "$stored_etag" ]; then
  echo "request_if_none_match=$stored_etag" >&2
else
  echo "request_if_none_match=none" >&2
fi
if [ -n "$stored_lm" ]; then
  echo "request_if_modified_since=$stored_lm" >&2
fi
if [ -z "$stored_etag" ] && [ -z "$stored_lm" ]; then
  echo "fetch=cold-full" >&2
fi

# Resolve the (injected) response status.
status="$SIM_STATUS"
if [ -z "$status" ]; then
  if [ -n "$stored_etag" ] || [ -n "$stored_lm" ]; then status=304; else status=200; fi
fi

new_etag="$stored_etag"
new_lm="$stored_lm"
new_hash="$stored_hash"

case "$status" in
  304)
    # Freshness proven without re-parsing; content_hash is NOT advanced.
    count_304=$((count_304 + 1))
    echo "response=304-not-modified" >&2
    echo "pipeline=skipped" >&2
    echo "freshness_timestamp_updated=$NOW" >&2
    ;;
  200)
    # Full pipeline; refresh stored headers. A changed body advances
    # content_hash and triggers the S-5 diff — never suppressed (§2.29).
    count_200=$((count_200 + 1))
    echo "response=200-ok" >&2
    echo "pipeline=full" >&2
    if [ -n "$ETAG" ]; then new_etag="$ETAG"; fi
    if [ -n "$LAST_MODIFIED" ]; then new_lm="$LAST_MODIFIED"; fi
    if [ -n "$BODY_HASH" ]; then
      if [ "$BODY_HASH" != "$stored_hash" ]; then
        echo "content_changed=true" >&2
        echo "diff=triggered" >&2
      else
        echo "content_changed=false" >&2
      fi
      new_hash="$BODY_HASH"
    fi
    ;;
  *)
    echo "conditional-get: bad --simulate-status $status (expected 200 or 304)" >&2
    exit 2
    ;;
esac

# Persist the updated store (etag + last_modified + content_hash + counters).
F="$F" SRC="$SOURCE_ID" E="$new_etag" L="$new_lm" H="$new_hash" C2="$count_200" C3="$count_304" TS="$NOW" ruby -rjson -e '
  h = {
    "source_id"    => ENV["SRC"],
    "etag"         => ENV["E"],
    "last_modified"=> ENV["L"],
    "content_hash" => ENV["H"],
    "last_checked" => ENV["TS"],
    "count_200"    => ENV["C2"].to_i,
    "count_304"    => ENV["C3"].to_i
  }
  File.write(ENV["F"], JSON.generate(h) + "\n")
'

# H-12 cost telemetry: per-source 304:200 ratio.
echo "ratio_304_200=$count_304:$count_200" >&2
exit 0
