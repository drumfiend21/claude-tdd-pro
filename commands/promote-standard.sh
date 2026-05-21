#!/usr/bin/env bash
# /promote-standard — S-7 + O-7 promotion entry point per §16:
# "/promote-standard <source> <section_id> with codebase-impact preview".
# Newly promoted rules land in rule_state: warn-only (canary state) per O-7.
set -uo pipefail

SOURCE=""; SECTION=""; TREE=""; DRY_RUN=0
SNAPSHOT=""; RULES_OUT=""; ROOT=""; PREVIEW_ONLY=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --rules-out) RULES_OUT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --preview-only) PREVIEW_ONLY=1; shift ;;
    -h|--help) echo "Usage: promote-standard.sh [<source> <section_id> --snapshot <yaml>] | [--source <id> --section <num> --tree <dir>] [--rules-out <dir>] [--root <dir>] [--dry-run] [--preview-only]"; exit 0 ;;
    -*) echo "promote-standard: unknown flag: $1" >&2; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# S-7 positional mode: <source> <section_id> --snapshot ... [--rules-out ...].
if [[ ${#POSITIONAL[@]} -ge 2 ]]; then
  S7_SOURCE="${POSITIONAL[0]}"
  S7_SECTION="${POSITIONAL[1]}"
  if [[ ! -f "$SNAPSHOT" ]]; then
    echo "promote-standard: unknown_source $S7_SOURCE (no snapshot at $SNAPSHOT)" >&2
    exit 2
  fi
  # Section presence check.
  if ! grep -qE "^[[:space:]]+${S7_SECTION}:" "$SNAPSHOT"; then
    echo "promote-standard: unknown_section $S7_SECTION (not present in $SNAPSHOT)" >&2
    exit 2
  fi
  # Codebase-impact preview when --root supplied.
  if [[ -n "$ROOT" && -d "$ROOT" ]]; then
    echo "promote-standard: codebase_impact_preview=invoked root=$ROOT source=$S7_SOURCE section_id=$S7_SECTION" >&2
    FILES_FLAGGED=0
    DETECTOR_LINE=$(grep -E "^[[:space:]]+${S7_SECTION}:" "$SNAPSHOT" | head -1)
    PATTERN=""
    if [[ "$DETECTOR_LINE" == *"detector:"* ]]; then
      PATTERN=$(echo "$DETECTOR_LINE" | sed -E 's/.*detector:[[:space:]]*"grep -lE ([^"]+)".*/\1/')
    fi
    if [[ -n "$PATTERN" && "$PATTERN" != "$DETECTOR_LINE" ]]; then
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if grep -qE "$PATTERN" "$f" 2>/dev/null; then
          FILES_FLAGGED=$((FILES_FLAGGED + 1))
        fi
      done < <(find "$ROOT" -type f 2>/dev/null)
    fi
    echo "promote-standard: files_flagged=$FILES_FLAGGED" >&2
    [[ "$PREVIEW_ONLY" -eq 1 ]] && exit 0
  fi
  RULE_ID="$(echo "${S7_SOURCE}-${S7_SECTION}" | tr '.' '-')"
  if [[ -n "$RULES_OUT" && -f "$RULES_OUT/$RULE_ID.yaml" ]]; then
    echo "promote-standard: already_promoted $RULE_ID exists in $RULES_OUT" >&2
    exit 2
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "promote-standard: planned: promote $S7_SOURCE:$S7_SECTION source=$S7_SOURCE section_id=$S7_SECTION dry_run=true" >&2
    exit 0
  fi
  if [[ -n "$RULES_OUT" ]]; then
    mkdir -p "$RULES_OUT"
    cat > "$RULES_OUT/$RULE_ID.yaml" <<YAML
id: $RULE_ID
class: published-standard
provenance:
  - class: published-standard
    source_id: $S7_SOURCE
    section_id: $S7_SECTION
    tier: 1
detector: from-snapshot
YAML
    echo "promote-standard: promoted $RULE_ID source=$S7_SOURCE section_id=$S7_SECTION rule_file=$RULES_OUT/$RULE_ID.yaml" >&2
  fi
  exit 0
fi

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
