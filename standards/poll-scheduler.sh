#!/usr/bin/env bash
# standards/poll-scheduler.sh — S-20 configurable-frequency / in-use polling
# scheduler (v1.12 §27).
#
# Per §27 S-20: "re-fetches each registry source on its resolved
# fetch_frequency cadence while a session is active (in-use detection via
# §2.13 active-flow stack). Cadence grammar per §2.28."
#
# Per §2.28 configurable-frequency in-use polling contract: fetch_frequency
# accepts a calendar token (daily|weekly|monthly|quarterly|on-demand) OR a
# sub-day interval matching ^[0-9]+(ms|s|m|h)$ OR the shorthand
# any-frequency. Default when unset is daily. Sub-day intervals fire only
# while a session is active (non-empty §2.13 active-flow stack); offline
# degrades to the calendar default with freshness offline-cached.
# any-frequency resolves via the S-22 FETCH-FREQUENCIES.yaml registry
# (override -> registry-default -> global daily).
#
# This script resolves a cadence to a millisecond interval, decides whether
# a fetch is due, gates sub-day cadences on session-in-use, and records the
# resolved cadence into a provenance standards_state block.
#
# CLI (interval math uses epoch-millis inputs for portability — no date
# parsing; ISO timestamps are not required by this layer):
#   --source-id <id>            (required) registry source id
#   --fetch-frequency <cadence> cadence token; unset -> daily
#   --now-ms <int>              current wall-clock in epoch millis (default 0)
#   --last-fetch-ms <int>       last successful fetch in epoch millis (default 0)
#   --active-flow-stub <path>   §2.13 stack file to consult for in-use
#                               (default .claude-tdd-pro/active-flow.stack)
#   --freq-file <path>          S-22 FETCH-FREQUENCIES.yaml for any-frequency
#   --emit-provenance <path>    write the standards_state block as JSON here
#
# stderr report tokens: interval_ms=<N>, resolved_cadence=<token>,
#   next-fetch-eta-ms=<N>, any-frequency-resolved=<token>,
#   decision=fetch|no-fetch-not-due|no-fire-offline|manual-on-demand,
#   freshness=fresh-within-fetch-frequency|offline-cached,
#   invalid_cadence=<token>.
#
# Exit codes: 0 success / 2 usage error or invalid cadence.

set -uo pipefail

SOURCE_ID=""
FETCH_FREQUENCY=""
NOW_MS="0"
LAST_FETCH_MS="0"
ACTIVE_FLOW_STUB=""
FREQ_FILE=""
EMIT_PROVENANCE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source-id)        SOURCE_ID="${2-}";        shift 2 ;;
    --fetch-frequency)  FETCH_FREQUENCY="${2-}";   shift 2 ;;
    --now-ms)           NOW_MS="${2-}";            shift 2 ;;
    --last-fetch-ms)    LAST_FETCH_MS="${2-}";     shift 2 ;;
    --active-flow-stub) ACTIVE_FLOW_STUB="${2-}";  shift 2 ;;
    --freq-file)        FREQ_FILE="${2-}";         shift 2 ;;
    --emit-provenance)  EMIT_PROVENANCE="${2-}";   shift 2 ;;
    -h|--help)
      echo "Usage: poll-scheduler.sh --source-id <id> [--fetch-frequency <cadence>] [--now-ms <int>] [--last-fetch-ms <int>] [--active-flow-stub <path>] [--freq-file <path>] [--emit-provenance <path>]" >&2
      exit 0
      ;;
    *) echo "poll-scheduler: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE_ID" ]; then
  echo "poll-scheduler: --source-id is required" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Cadence resolution. Echoes "<interval_ms> <resolved_token> <class>" on
# success; returns 2 on an invalid cadence. class is calendar|subday|manual.
# ---------------------------------------------------------------------------
resolve_cadence() {
  c="$1"
  case "$c" in
    ""|daily)  echo "86400000 daily calendar" ;;
    weekly)    echo "604800000 weekly calendar" ;;
    monthly)   echo "2592000000 monthly calendar" ;;
    quarterly) echo "7776000000 quarterly calendar" ;;
    on-demand) echo "-1 on-demand manual" ;;
    *)
      # §2.28 sub-day interval grammar: ^[0-9]+(ms|s|m|h)$
      if printf '%s' "$c" | grep -Eq '^[0-9]+(ms|s|m|h)$'; then
        num=$(printf '%s' "$c" | sed -E 's/(ms|s|m|h)$//')
        unit=$(printf '%s' "$c" | sed -E 's/^[0-9]+//')
        # §27.5 grammar floor is 1ms; reject a zero interval.
        if [ "$num" -eq 0 ] 2>/dev/null; then return 2; fi
        case "$unit" in
          ms) ms="$num" ;;
          s)  ms=$((num * 1000)) ;;
          m)  ms=$((num * 60000)) ;;
          h)  ms=$((num * 3600000)) ;;
        esac
        echo "$ms $c subday"
      else
        return 2
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# any-frequency (§2.28 shorthand) resolves via the S-22 FETCH-FREQUENCIES
# registry. S-20 ships the handoff: read a `default:` cadence from the file
# when present, else fall back to the global default `daily`. The full
# per-registry / per-source override resolution is S-22's substrate.
# ---------------------------------------------------------------------------
RESOLVED_FREQUENCY="$FETCH_FREQUENCY"
if [ "$FETCH_FREQUENCY" = "any-frequency" ]; then
  af="daily"
  if [ -n "$FREQ_FILE" ] && [ -f "$FREQ_FILE" ]; then
    fileval=$(grep -E '^[[:space:]]*default:' "$FREQ_FILE" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*default:[[:space:]]*//' | tr -d '"' | tr -d ' ')
    if [ -n "$fileval" ]; then af="$fileval"; fi
  fi
  RESOLVED_FREQUENCY="$af"
  echo "any-frequency-resolved=$af" >&2
fi

if ! parsed=$(resolve_cadence "$RESOLVED_FREQUENCY"); then
  echo "invalid_cadence=$FETCH_FREQUENCY" >&2
  exit 2
fi

# Split "<ms> <token> <class>" without arrays.
set -- $parsed
INTERVAL_MS="$1"
RESOLVED_CADENCE="$2"
CLASS="$3"

echo "interval_ms=$INTERVAL_MS" >&2
echo "resolved_cadence=$RESOLVED_CADENCE" >&2

# next-fetch-eta: last successful fetch + interval (manual cadence has none).
if [ "$CLASS" = "manual" ]; then
  echo "next-fetch-eta-ms=manual" >&2
else
  echo "next-fetch-eta-ms=$((LAST_FETCH_MS + INTERVAL_MS))" >&2
fi

# §2.13 in-use detection: a non-empty active-flow stack proxies "in use".
STACK="$ACTIVE_FLOW_STUB"
if [ -z "$STACK" ]; then STACK=".claude-tdd-pro/active-flow.stack"; fi
IN_USE=0
if [ -f "$STACK" ] && [ -s "$STACK" ]; then IN_USE=1; fi

# Decision + freshness (§2.8 freshness_at_generation enum).
FRESHNESS="fresh-within-fetch-frequency"
if [ "$CLASS" = "manual" ]; then
  echo "decision=manual-on-demand" >&2
else
  elapsed=$((NOW_MS - LAST_FETCH_MS))
  if [ "$elapsed" -lt "$INTERVAL_MS" ]; then
    echo "decision=no-fetch-not-due" >&2
  elif [ "$CLASS" = "subday" ] && [ "$IN_USE" -eq 0 ]; then
    FRESHNESS="offline-cached"
    echo "decision=no-fire-offline" >&2
    echo "freshness=offline-cached" >&2
  else
    echo "decision=fetch" >&2
    echo "freshness=fresh-within-fetch-frequency" >&2
  fi
fi

# §2.28: record the resolved cadence into the §2.8 provenance standards_state
# block when requested.
if [ -n "$EMIT_PROVENANCE" ]; then
  printf '{"standards_state":{"%s":{"fetch_frequency":"%s","resolved_interval_ms":%s,"freshness_at_generation":"%s"}}}\n' \
    "$SOURCE_ID" "$RESOLVED_CADENCE" "$INTERVAL_MS" "$FRESHNESS" > "$EMIT_PROVENANCE"
fi

exit 0
