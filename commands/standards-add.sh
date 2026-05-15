#!/usr/bin/env bash
# /standards-add — G-9 auto-scaffold for STANDARDS-URLS.yaml entry.
# Per §16 G-9: routes to <inferred-namespace>/<id>.yaml via id prefix
# or operator-set --source-namespace. Creates folder + populated
# source: header.
set -uo pipefail

URL=""; ID=""; TIER=""; APPLIES_TO=""; SOURCE_NAMESPACE=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    --applies-to) APPLIES_TO="$2"; shift 2 ;;
    --source-namespace) SOURCE_NAMESPACE="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    *) echo "standards-add: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$URL" || -z "$ID" || -z "$TIER" || -z "$APPLIES_TO" || -z "$TREE" ]] && {
  echo "standards-add: --url, --id, --tier, --applies-to, --tree required" >&2; exit 2; }

# Infer namespace: explicit --source-namespace wins; else use the
# first label of the URL hostname (matches §17 G-1 source-folder
# convention where tree/<publisher>/<file>.yaml is the layout).
NS="$SOURCE_NAMESPACE"
if [[ -z "$NS" ]]; then
  NS=$(echo "$URL" | sed -E 's|https?://([^./]+).*|\1|')
fi
mkdir -p "$TREE/$NS"
TARGET="$TREE/$NS/$ID.yaml"
if [[ -f "$TARGET" ]] || [[ -f "$TREE/$NS/existing.yaml" && "$ID" == "existing" ]]; then
  echo "standards-add: id $ID collision (file already exists at $TARGET)" >&2
  exit 2
fi
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PUBLISHER=$(echo "$URL" | sed -E 's|https?://([^/]+)/.*|\1|')
cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "$PUBLISHER"
  authoritative_url: $URL
  registry_link: STANDARDS-URLS.yaml
  fetched_at: "$TS"
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: medium
  license_note: "review-required"
rules: []
recommended_set: []
all_set: []
YAML
echo "standards-add: created $TARGET" >&2
