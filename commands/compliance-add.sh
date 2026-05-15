#!/usr/bin/env bash
# compliance-add.sh — C-16 substrate. Adds an entry to the
# .claude-tdd-pro/COMPLIANCE-URLS.yaml catalog.
#
# Per architecture section 16 C-16: "/compliance-add <url> with $EDITOR
# prompt for why_authoritative."
#
# Usage:
#   compliance-add.sh <url> --id <id> --catalog <path>
#                     [--why-authoritative-file <file>]
#                     [--target <tree-dir>]      # C-14 sync to scaffold folder
#                     [--paywalled --document-url <url> --attribution <name>]
#                     [--jurisdiction <name>]    # auto-extracted from URL when omitted
#                     [--dry-run]

set -uo pipefail

URL=""
ID=""
CATALOG=""
WHY_FILE=""
TARGET_TREE=""
PAYWALLED=0
DOC_URL=""
ATTRIBUTION=""
JURISDICTION=""
DRY_RUN=0
LEGACY_TREE=""

# First positional arg is the URL (unless it starts with --).
if [[ $# -gt 0 && "${1:0:2}" != "--" && "$1" != "-h" ]]; then
  URL="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    --why-authoritative-file) WHY_FILE="$2"; shift 2 ;;
    --target) TARGET_TREE="$2"; shift 2 ;;
    --tree) LEGACY_TREE="$2"; shift 2 ;;
    --paywalled) PAYWALLED=1; shift ;;
    --document-url) DOC_URL="$2"; shift 2 ;;
    --attribution) ATTRIBUTION="$2"; shift 2 ;;
    --jurisdiction) JURISDICTION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: compliance-add.sh <url> --id <id> --catalog <path> [--why-authoritative-file <file>] [--target <dir>] [--paywalled --document-url <url> --attribution <name>] [--jurisdiction <name>] [--dry-run]"
      echo "       compliance-add.sh --url <u> --id <id> --jurisdiction <j> --tree <dir>  (legacy G-9 mode)"
      exit 0
      ;;
    *) shift ;;
  esac
done

# Legacy G-9 mode: --tree without --catalog.
if [[ -n "$LEGACY_TREE" && -z "$CATALOG" ]]; then
  if [[ -z "$URL" || -z "$ID" || -z "$JURISDICTION" ]]; then
    echo "compliance-add (legacy mode): --url, --id, --jurisdiction required" >&2
    exit 2
  fi
  case "$JURISDICTION" in
    "US Federal"|"US"|"USA") NS="us-government" ;;
    "EU"|"European Union") NS="european-union" ;;
    *) NS=$(echo "$JURISDICTION" | tr '[:upper:] ' '[:lower:]-') ;;
  esac
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "compliance-add: dry-run; would add id=$ID url=$URL jurisdiction=$JURISDICTION ns=$NS (no writes)" >&2
    exit 0
  fi
  mkdir -p "$LEGACY_TREE/$NS"
  TARGET="$LEGACY_TREE/$NS/$ID.yaml"
  [[ -f "$TARGET" ]] && { echo "compliance-add: id $ID collision at $TARGET" >&2; exit 2; }
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  PUB=$(echo "$URL" | sed -E 's|https?://([^/]+)/.*|\1|')
  cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "$PUB"
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
  exit 0
fi

if [[ -z "$URL" ]]; then
  echo "compliance-add: positional <url> argument is required" >&2
  exit 2
fi

if [[ -z "$ID" || -z "$CATALOG" ]]; then
  echo "compliance-add: --id and --catalog required" >&2
  exit 2
fi

if [[ "$PAYWALLED" -eq 1 && ( -z "$DOC_URL" || -z "$ATTRIBUTION" ) ]]; then
  echo "compliance-add: --paywalled requires --document-url and --attribution (paywalled sources need a document_url and attribution to record)" >&2
  exit 2
fi

# Pop $EDITOR if --why-authoritative-file not given AND $EDITOR is set.
if [[ -z "$WHY_FILE" && -n "${EDITOR:-}" ]]; then
  WHY_TMP=$(mktemp)
  "$EDITOR" "$WHY_TMP" >/dev/null 2>&1 || true
  WHY_FILE="$WHY_TMP"
fi

if [[ -z "$WHY_FILE" || ! -f "$WHY_FILE" ]]; then
  echo "compliance-add: --why-authoritative-file required (or set \$EDITOR for interactive prompt)" >&2
  exit 2
fi

WHY_LINES=$(grep -cv '^[[:space:]]*$' "$WHY_FILE" 2>/dev/null || echo 0)
WHY_LINES=$(echo "$WHY_LINES" | tr -d ' \n')
if [[ "${WHY_LINES:-0}" -lt 3 ]]; then
  echo "compliance-add: why_authoritative must have at least 3 non-empty lines (got: ${WHY_LINES:-0})" >&2
  exit 2
fi

# Auto-extract jurisdiction from URL when not given.
if [[ -z "$JURISDICTION" ]]; then
  case "$URL" in
    *eur-lex.europa.eu*|*ec.europa.eu*|*edpb.europa.eu*|*gdpr.eu*) JURISDICTION="european-union" ;;
    *.gov*|*nist.gov*|*whitehouse.gov*) JURISDICTION="us-government" ;;
    *iso.org*) JURISDICTION="international" ;;
    *aicpa.org*) JURISDICTION="us" ;;
    *) JURISDICTION="unspecified" ;;
  esac
fi

# Auto-extract publisher from URL — translate well-known hosts to readable names.
HOST=$(echo "$URL" | sed -E 's|https?://(www\.)?([^/]+)/?.*|\2|')
case "$HOST" in
  eur-lex.europa.eu|ec.europa.eu|edpb.europa.eu) PUBLISHER="European Union ($HOST)" ;;
  *.gov|nist.gov|whitehouse.gov|*.nist.gov) PUBLISHER="US Government ($HOST)" ;;
  iso.org|*.iso.org) PUBLISHER="International Organization for Standardization ($HOST)" ;;
  aicpa.org|*.aicpa.org) PUBLISHER="AICPA ($HOST)" ;;
  *) PUBLISHER="$HOST" ;;
esac

# Catalog must exist (created empty if needed).
if [[ ! -f "$CATALOG" ]]; then
  mkdir -p "$(dirname "$CATALOG")"
  : > "$CATALOG"
fi

# Reject duplicate id.
if grep -qE "^- id: $ID\$|^- id: $ID[[:space:]]*\$" "$CATALOG"; then
  echo "compliance-add: id $ID already exists in $CATALOG (would overwrite an existing entry; use compliance-remove first)" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "compliance-add: dry-run; would add id=$ID url=$URL jurisdiction=$JURISDICTION (no writes to $CATALOG or $TARGET_TREE)" >&2
  exit 0
fi

# Append entry to catalog.
{
  cat "$CATALOG"
  echo "- id: $ID"
  echo "  name: $ID"
  echo "  url: $URL"
  echo "  authoritative_publisher: $PUBLISHER"
  echo "  jurisdiction: $JURISDICTION"
  echo "  applicable_to: [unspecified]"
  echo "  identifier_scheme: $ID"
  echo "  why_authoritative: |"
  while IFS= read -r line; do
    echo "    $line"
  done < "$WHY_FILE"
  echo "  fetch_frequency: weekly"
  echo "  legal_review_required: true"
  echo "  paywalled: $([ "$PAYWALLED" -eq 1 ] && echo true || echo false)"
  if [[ "$PAYWALLED" -eq 1 ]]; then
    echo "  document_url: $DOC_URL"
    echo "  attribution: $ATTRIBUTION"
  fi
  echo "  added_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$CATALOG.tmp" && mv "$CATALOG.tmp" "$CATALOG"

# Trigger C-14 sync to scaffold folder.
if [[ -n "$TARGET_TREE" ]]; then
  SCAFFOLD_DIR="$TARGET_TREE/$JURISDICTION/$ID"
  mkdir -p "$SCAFFOLD_DIR"
  echo "compliance-add: scaffolded folder $SCAFFOLD_DIR (C-14 sync)" >&2
fi

echo "compliance-add: added $ID ($URL, jurisdiction=$JURISDICTION) to $CATALOG" >&2
exit 0
