#!/usr/bin/env bash
# /compliance-add — G-9 auto-scaffold for COMPLIANCE-URLS.yaml entry.
# Per §16 G-9: namespace by jurisdiction (US Federal → us-government,
# EU → european-union).
set -uo pipefail

URL=""; ID=""; JURISDICTION=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --jurisdiction) JURISDICTION="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    *) echo "compliance-add: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$URL" || -z "$ID" || -z "$JURISDICTION" || -z "$TREE" ]] && {
  echo "compliance-add: --url, --id, --jurisdiction, --tree required" >&2; exit 2; }

case "$JURISDICTION" in
  "US Federal"|"US"|"USA") NS="us-government" ;;
  "EU"|"European Union") NS="european-union" ;;
  *) NS=$(echo "$JURISDICTION" | tr '[:upper:] ' '[:lower:]-') ;;
esac
mkdir -p "$TREE/$NS"
TARGET="$TREE/$NS/$ID.yaml"
[[ -f "$TARGET" ]] && { echo "compliance-add: id $ID collision at $TARGET" >&2; exit 2; }
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PUBLISHER=$(echo "$URL" | sed -E 's|https?://([^/]+)/.*|\1|')
cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "$PUBLISHER"
  authoritative_url: "$URL"
  registry_link: COMPLIANCE-URLS.yaml
  fetched_at: "$TS"
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: low
  license_note: "review-required"
  jurisdiction: "$JURISDICTION"
rules: []
recommended_set: []
all_set: []
YAML
echo "compliance-add: created $TARGET (jurisdiction=$JURISDICTION)" >&2
