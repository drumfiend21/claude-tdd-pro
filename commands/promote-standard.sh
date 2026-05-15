#!/usr/bin/env bash
# /promote-standard — S-7 + O-7 promotion entry point per §16:
# "/promote-standard <source> <section_id> with codebase-impact preview".
# Newly promoted rules land in rule_state: warn-only (canary state) per O-7.
set -uo pipefail

SOURCE=""; SECTION=""; TREE=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: promote-standard.sh --source <id> --section <num> [--tree <dir>] [--dry-run]"; exit 0 ;;
    *) echo "promote-standard: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "promote-standard: dry-run; would promote $SOURCE section $SECTION (no writes)" >&2
  exit 0
fi

[[ -z "$SOURCE" || -z "$SECTION" || -z "$TREE" ]] && {
  echo "promote-standard: --source, --section, --tree required" >&2; exit 2; }

# Infer namespace from source id (e.g. google-tsguide -> google folder).
NS=$(echo "$SOURCE" | cut -d- -f1)
mkdir -p "$TREE/$NS"
BASENAME=$(echo "$SOURCE" | cut -d- -f2-)
TARGET="$TREE/$NS/${BASENAME}.yaml"

if [[ -f "$TARGET" ]]; then
  echo "promote-standard: $TARGET already exists (use --force to overwrite)" >&2
  exit 2
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RULE_ID="g-${BASENAME}-001"
cat > "$TARGET" <<YAML
source:
  id: $SOURCE
  authoritative_publisher: "(pending)"
  authoritative_url: "https://example.com/$SOURCE"
  registry_link: STANDARDS-URLS.yaml
  fetched_at: $TS
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: medium
  license_note: "review-required"
rules:
  - id: $RULE_ID
    name: $RULE_ID
    description: "Promoted from $SOURCE section $SECTION"
    detector: "rubric/detectors/${RULE_ID}.sh"
    rule_state: warn-only
    severity: P1
    rule_state_history: [{timestamp: $TS, from: none, to: warn-only, reason: promotion}]
recommended_set: [$RULE_ID]
all_set: [$RULE_ID]
YAML

echo "promote-standard: created $TARGET (rule_state: warn-only canary)" >&2
