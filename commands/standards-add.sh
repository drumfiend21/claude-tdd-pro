#!/usr/bin/env bash
# /standards-add — S-14 + G-9 entry point per §16:
#   "/standards-add <url>." (S-14)
#   "STANDARDS-URLS.yaml entry → <inferred-namespace>/<id>.yaml ..." (G-9)
#
# Two-stage flow:
#   1. Append entry to .claude-tdd-pro/STANDARDS-URLS.yaml (operator
#      registry per §2.6 operator-facing schema)
#   2. When --tree given: also auto-scaffold the source-folder file
#      at <tree>/<inferred-namespace>/<id>.yaml (G-9 chain)
#
# Usage:
#   standards-add.sh <url> [--id <id>] [--tier 1|2]
#                     [--applies-to <lang>]
#                     [--source-namespace <ns>] [--tree <dir>]
#                     [--dry-run] [--emit-audit <jsonl>]
#   (Also accepts --url <url> for backward-compat with G-9 invocation.)

set -uo pipefail

URL=""; ID=""; TIER=""; APPLIES_TO=""; SOURCE_NAMESPACE=""; TREE=""
DRY_RUN=0; EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    --applies-to) APPLIES_TO="$2"; shift 2 ;;
    --source-namespace) SOURCE_NAMESPACE="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -*) echo "standards-add: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$URL" ]] && URL="$1" || { echo "standards-add: unexpected arg: $1" >&2; exit 2; }; shift ;;
  esac
done
[[ -z "$URL" ]] && { echo "standards-add: <url> required" >&2; exit 2; }
[[ "$URL" != https://* ]] && { echo "standards-add: url must be https:// (got $URL); https required" >&2; exit 2; }

# Infer id from URL when omitted: <hostname-first-label>-<basename-no-ext>.
if [[ -z "$ID" ]]; then
  HOST_LABEL=$(echo "$URL" | sed -E 's|https?://([^./]+).*|\1|')
  BASENAME=$(basename "$URL" | sed -E 's|\.[a-z]+$||')
  ID="${HOST_LABEL}-${BASENAME}"
fi

REGISTRY=".claude-tdd-pro/STANDARDS-URLS.yaml"
mkdir -p .claude-tdd-pro

# Collision check against existing registry entries.
if [[ -f "$REGISTRY" ]] && grep -qE "^- id: ${ID}\$" "$REGISTRY"; then
  echo "standards-add: id $ID collision (already present in $REGISTRY)" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "standards-add: dry-run; would append id=$ID url=$URL" >&2
  exit 0
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PUBLISHER=$(echo "$URL" | sed -E 's|https?://([^/]+)/?.*|\1|')
TIER_VAL="${TIER:-1}"
APPLIES_VAL="${APPLIES_TO:-universal}"

# Append to registry.
cat >> "$REGISTRY" <<YAML
- id: $ID
  name: "${PUBLISHER}: $ID"
  url: $URL
  tier: $TIER_VAL
  applies_to: [${APPLIES_VAL}]
  fetch_frequency: daily
  added_by: operator
  added_at: $TS
YAML

# Audit log.
if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  printf '{"command":"standards-add","id":"%s","url":"%s","ts":"%s"}\n' "$ID" "$URL" "$TS" >> "$EMIT_AUDIT"
fi

# G-9 folder scaffold chain when --tree given.
if [[ -n "$TREE" ]]; then
  NS="$SOURCE_NAMESPACE"
  if [[ -z "$NS" ]]; then
    NS=$(echo "$URL" | sed -E 's|https?://([^./]+).*|\1|')
  fi
  mkdir -p "$TREE/$NS"
  TARGET="$TREE/$NS/$ID.yaml"
  if [[ -f "$TARGET" ]] || [[ -f "$TREE/$NS/existing.yaml" && "$ID" == "existing" ]]; then
    echo "standards-add: id $ID collision (folder file already exists at $TARGET)" >&2
    exit 2
  fi
  cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "$PUBLISHER"
  authoritative_url: $URL
  registry_link: STANDARDS-URLS.yaml
  fetched_at: $TS
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: medium
  license_note: "review-required"
rules: []
recommended_set: []
all_set: []
YAML
  echo "standards-add: scaffolded $TARGET" >&2
fi

echo "standards-add: registered $ID in $REGISTRY" >&2
