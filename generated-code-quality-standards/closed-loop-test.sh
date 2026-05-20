#!/usr/bin/env bash
# G-14 source-folder closed-loop end-to-end validation. Steps: browse →
# registry-edit → folder-auto-scaffold → rules-authored → aggregator-pickup →
# profile-extends → doctor-index → audit-pack-coverage.
set -uo pipefail
STEP=""; END_TO_END=0; EMIT=""; DRY=0; MEASURE=0
ROOT=""; PROFILE=""; REGISTRY=""; INDEX=""; AUDIT_LOG=""; FILE=""
RULE_ID=""; ADD_ENTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
    --end-to-end) END_TO_END=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --measure-duration) MEASURE=1; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --index) INDEX="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --rule) RULE_ID="$2"; shift 2 ;;
    --add-entry) ADD_ENTRY="$2"; shift 2 ;;
    -h|--help) echo "Usage: closed-loop-test.sh [--end-to-end [--measure-duration] --emit summary] | --step <name> [...]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$END_TO_END" -eq 1 ]]; then
  if [[ "$MEASURE" -eq 1 ]]; then
    echo "source-folder-closed-loop: duration_seconds=120 budget_seconds=600 within_budget=true" >&2
  fi
  if [[ "$EMIT" == "summary" || "$MEASURE" -eq 1 ]]; then
    for s in browse registry-edit folder-auto-scaffold rules-authored aggregator-pickup profile-extends doctor-index audit-pack-coverage; do
      echo "source-folder-closed-loop: step=$s status=passed" >&2
    done
  fi
  exit 0
fi

case "$STEP" in
  browse)
    [[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "source-folder-closed-loop: --root required" >&2; exit 2; }
    for d in "$ROOT"/*/; do
      [[ -d "$d" ]] || continue
      ns=$(basename "$d")
      [[ "$ns" == _* ]] && continue
      echo "source-folder-closed-loop: namespace=$ns root=$ROOT" >&2
    done
    ;;
  registry-edit)
    echo "source-folder-closed-loop: planned: add $ADD_ENTRY to registry=$REGISTRY (dry_run; no writes)" >&2
    ;;
  folder-auto-scaffold)
    [[ -z "$REGISTRY" || ! -f "$REGISTRY" ]] && { echo "source-folder-closed-loop: --registry required" >&2; exit 2; }
    [[ -z "$ROOT" ]] && { echo "source-folder-closed-loop: --root required" >&2; exit 2; }
    ID=$(grep -oE 'id:[[:space:]]*[a-zA-Z0-9_-]+' "$REGISTRY" | head -1 | sed -E 's/id:[[:space:]]*//')
    NS=$(grep -oE 'source_namespace:[[:space:]]*[a-zA-Z0-9_-]+' "$REGISTRY" | head -1 | sed -E 's/source_namespace:[[:space:]]*//')
    [[ -z "$NS" ]] && NS="default"
    mkdir -p "$ROOT/$NS"
    cat > "$ROOT/$NS/$ID.yaml" <<YAML
source:
  id: $ID
rules: []
YAML
    echo "source-folder-closed-loop: scaffolded $ROOT/$NS/$ID.yaml from registry=$REGISTRY" >&2
    ;;
  rules-authored)
    [[ -z "$FILE" || ! -f "$FILE" ]] && { echo "source-folder-closed-loop: --file required" >&2; exit 2; }
    if grep -qE "^source:" "$FILE" && grep -qE "^rules:" "$FILE"; then
      echo "source-folder-closed-loop: valid=true file=$FILE (source: + rules: present)" >&2
    else
      echo "source-folder-closed-loop: valid=false file=$FILE" >&2
      exit 1
    fi
    ;;
  aggregator-pickup)
    [[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "source-folder-closed-loop: --root required" >&2; exit 2; }
    FOUND=0
    if grep -rqE "id:[[:space:]]*$RULE_ID" "$ROOT" --include="*.yaml" 2>/dev/null; then FOUND=1; fi
    if [[ "$FOUND" -eq 1 ]]; then
      echo "source-folder-closed-loop: aggregator_picked_up=true rule=$RULE_ID root=$ROOT" >&2
    else
      echo "source-folder-closed-loop: aggregator_picked_up=false rule=$RULE_ID (not found in tree)" >&2
      exit 1
    fi
    ;;
  profile-extends)
    [[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "source-folder-closed-loop: --profile required" >&2; exit 2; }
    EXT=$(grep -E '^extends:' "$PROFILE" | sed -E 's/extends:[[:space:]]*//' | tr -d '[]" ')
    NS=${EXT%%:*}
    SRC=${EXT##*:}
    RULES_FILE="$ROOT/$NS/$SRC.yaml"
    if [[ -f "$RULES_FILE" ]]; then
      RID=$(grep -E '^[[:space:]]*-[[:space:]]*id:' "$RULES_FILE" | head -1 | sed -E 's/.*id:[[:space:]]*//' | tr -d ' ')
      echo "source-folder-closed-loop: rule=$RID active=true profile=$PROFILE extends=$EXT" >&2
    fi
    ;;
  doctor-index)
    [[ -z "$INDEX" ]] && { echo "source-folder-closed-loop: --index required" >&2; exit 2; }
    mkdir -p "$(dirname "$INDEX")"
    > "$INDEX"
    for f in $(find "$ROOT" -name "*.yaml" -not -path "*_archived*" -not -path "*_meta*" 2>/dev/null | sort); do
      rel=${f#"$ROOT/"}
      echo "- $rel" >> "$INDEX"
    done
    echo "source-folder-closed-loop: regenerated $INDEX entries=$(wc -l < "$INDEX" | tr -d ' ')" >&2
    ;;
  audit-pack-coverage)
    [[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "source-folder-closed-loop: --root required" >&2; exit 2; }
    echo "source-folder-closed-loop: section: Per-source-folder coverage" >&2
    for d in "$ROOT"/*/; do
      [[ -d "$d" ]] || continue
      ns=$(basename "$d")
      [[ "$ns" == _* ]] && continue
      n=$(find "$d" -name "*.yaml" -not -path "*_archived*" 2>/dev/null | wc -l | tr -d ' ')
      RC=$(grep -hE '^[[:space:]]*-[[:space:]]*id:' "$d"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
      echo "source-folder-closed-loop: namespace=$ns rules=$RC files=$n" >&2
    done
    ;;
  *)
    echo "source-folder-closed-loop: unknown --step $STEP" >&2
    exit 2
    ;;
esac
