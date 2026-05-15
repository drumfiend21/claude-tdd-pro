#!/usr/bin/env bash
# /pr-source-add — G-9 auto-scaffold for PR-SOURCES.yaml entry.
# Per §16 G-9: namespace by source_class:
#   federal-financial-regulator → us-government/
#   financial-industry          → finance-industry/
#   gold-standard-process       → linux-foundation/
set -uo pipefail

GITHUB=""; ID=""; SOURCE_CLASS=""; TREE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --github) GITHUB="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --source-class) SOURCE_CLASS="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    *) echo "pr-source-add: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$GITHUB" || -z "$ID" || -z "$SOURCE_CLASS" || -z "$TREE" ]] && {
  echo "pr-source-add: --github, --id, --source-class, --tree required" >&2; exit 2; }

case "$SOURCE_CLASS" in
  federal-financial-regulator) NS="us-government" ;;
  financial-industry) NS="finance-industry" ;;
  gold-standard-process) NS="linux-foundation" ;;
  *) NS="industry-self-regulatory" ;;
esac
mkdir -p "$TREE/$NS"
TARGET="$TREE/$NS/$ID.yaml"
[[ -f "$TARGET" ]] && { echo "pr-source-add: id $ID collision at $TARGET" >&2; exit 2; }
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
URL="https://github.com/$GITHUB"
cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "github.com/$GITHUB"
  authoritative_url: "$URL"
  registry_link: PR-SOURCES.yaml
  fetched_at: "$TS"
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: medium
  license_note: "see-repo"
  source_class: "$SOURCE_CLASS"
rules: []
recommended_set: []
all_set: []
YAML
echo "pr-source-add: created $TARGET (class=$SOURCE_CLASS)" >&2
