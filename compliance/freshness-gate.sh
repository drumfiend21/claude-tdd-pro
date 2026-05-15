#!/usr/bin/env bash
# compliance/freshness-gate.sh — C-15 daily-fresh compliance gate.
# Symmetric to standards/freshness-gate.sh; tracks
# .claude-tdd-pro/compliance-last-fetch/<framework-id>.txt markers.
# --paywalled --require-attestation refuses citation when
# compliance/attestations/<id>.yaml is absent.
set -uo pipefail

FRAMEWORK_ID=""; FF=""; NOW_ISO=""; SKIP_FRESH=0; PAYWALLED=0
REQUIRE_ATTESTATION=0; EMIT_AUDIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework-id) FRAMEWORK_ID="$2"; shift 2 ;;
    --fetch-frequency) FF="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --skip-fresh) SKIP_FRESH=1; shift ;;
    --paywalled) PAYWALLED=1; shift ;;
    --require-attestation) REQUIRE_ATTESTATION=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    *) echo "freshness-gate: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$FRAMEWORK_ID" ]] && { echo "freshness-gate: --framework-id required" >&2; exit 2; }

# Paywalled + require-attestation: refuse citation if no attestation.
if [[ "$PAYWALLED" -eq 1 && "$REQUIRE_ATTESTATION" -eq 1 ]]; then
  if [[ ! -f "compliance/attestations/$FRAMEWORK_ID.yaml" ]]; then
    echo "freshness-gate: paywalled framework $FRAMEWORK_ID requires attestation; required attestation file compliance/attestations/$FRAMEWORK_ID.yaml not found" >&2
    exit 2
  fi
fi

mkdir -p .claude-tdd-pro/compliance-last-fetch
MARKER=".claude-tdd-pro/compliance-last-fetch/$FRAMEWORK_ID.txt"
[[ -z "$FF" ]] && FF="weekly"
[[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
WINDOW_HOURS=168
case "$FF" in
  hourly) WINDOW_HOURS=1 ;;
  daily) WINDOW_HOURS=24 ;;
  weekly) WINDOW_HOURS=168 ;;
  monthly) WINDOW_HOURS=720 ;;
esac

if [[ "$SKIP_FRESH" -eq 1 ]]; then
  if [[ -n "$EMIT_AUDIT" ]]; then
    mkdir -p "$(dirname "$EMIT_AUDIT")"
    printf '{"action":"skip-fresh","framework_id":"%s","ts":"%s"}\n' "$FRAMEWORK_ID" "$NOW_ISO" >> "$EMIT_AUDIT"
  fi
  exit 0
fi

if [[ ! -f "$MARKER" ]]; then
  echo "freshness-gate: $FRAMEWORK_ID stale (never fetched)" >&2
  exit 1
fi

LAST=$(cat "$MARKER")
NOW_TS=$(NOW="$NOW_ISO" node -e 'process.stdout.write(String(Math.floor(new Date(process.env.NOW).getTime()/1000)))')
LAST_TS=$(LAST="$LAST" node -e 'process.stdout.write(String(Math.floor(new Date(process.env.LAST).getTime()/1000)))')
AGE_HOURS=$(( (NOW_TS - LAST_TS) / 3600 ))
LIMIT_SEC=$(( WINDOW_HOURS * 3600 ))
if [[ $((NOW_TS - LAST_TS)) -gt $LIMIT_SEC ]]; then
  echo "freshness-gate: $FRAMEWORK_ID stale (age ${AGE_HOURS}h > ${WINDOW_HOURS}h ${FF} window)" >&2
  exit 1
fi
exit 0
