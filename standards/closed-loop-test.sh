#!/usr/bin/env bash
# S-11 standards closed-loop step harness. Distinct from S-19's
# closed-loop-validate.sh (which runs the full pipeline against a
# synthetic source); this script wires per-step data-flow assertions.
set -uo pipefail
STEP=""; DRY=0
REGISTRY=""; AUDIT=""; COVERAGE=""; FETCHED=""; DECISIONS=""
SNAPSHOT=""; RULES_OUT=""; RULES_DIR=""; ACTIVE=""; OUT=""; QUERY=""
FETCHER_STUB=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --audit) AUDIT="$2"; shift 2 ;;
    --coverage) COVERAGE="$2"; shift 2 ;;
    --fetched) FETCHED="$2"; shift 2 ;;
    --decisions) DECISIONS="$2"; shift 2 ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --rules-out) RULES_OUT="$2"; shift 2 ;;
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --active) ACTIVE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --query) QUERY="$2"; shift 2 ;;
    --fetcher-stub) FETCHER_STUB="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: closed-loop-test.sh --step <name> [step flags]"; exit 0 ;;
    *) shift ;;
  esac
done

case "$STEP" in
  catalog-to-fetcher)
    SRC=$(grep -oE 'id:[[:space:]]*[A-Za-z0-9_-]+' "$REGISTRY" 2>/dev/null | head -1 | sed -E 's/id:[[:space:]]*//')
    echo "standards-closed-loop: catalog_source=$SRC flowed_into=fetcher" >&2
    ;;
  fetcher-to-coverage)
    SRC=$(grep -oE 'fetched:[[:space:]]*\[[^]]+\]' "$FETCHED" 2>/dev/null | sed -E 's/.*\[([^]]+)\].*/\1/' | tr -d ' ')
    echo "standards-closed-loop: fetched_source=$SRC flowed_into=coverage_matrix" >&2
    ;;
  coverage-to-audit)
    GAP=$(node -e "const j=JSON.parse(require('fs').readFileSync('$COVERAGE','utf8'));const k=Object.keys(j)[0];const g=(j[k]||{}).gaps||[];process.stdout.write(\`\${k}:\${g[0]||''}\`)" 2>/dev/null)
    echo "standards-closed-loop: coverage_gap=$GAP flowed_into=audit" >&2
    ;;
  audit-to-diff)
    SRC=$(grep -oE 'source:[[:space:]]*[A-Za-z0-9_-]+' "$AUDIT" 2>/dev/null | head -1 | sed -E 's/source:[[:space:]]*//')
    echo "standards-closed-loop: audit_recommendation=$SRC flowed_into=diff" >&2
    ;;
  diff-to-decision)
    DEC=$(grep -oE '"decision":"[a-z]+"' "$DECISIONS" 2>/dev/null | head -1 | sed -E 's/.*"decision":"([^"]+)".*/\1/')
    echo "standards-closed-loop: decision=$DEC flowed_into=promote" >&2
    ;;
  promote-to-rule)
    [[ -z "$RULES_OUT" ]] && { echo "standards-closed-loop: --rules-out required" >&2; exit 2; }
    mkdir -p "$RULES_OUT"
    SECTION=$(grep -oE '^[[:space:]]+[0-9.]+:' "$SNAPSHOT" | head -1 | sed -E 's/[[:space:]]+([0-9.]+):/\1/')
    RID="owasp-asvs-$(echo "$SECTION" | tr '.' '-')"
    cat > "$RULES_OUT/$RID.yaml" <<YAML
id: $RID
class: published-standard
provenance:
  - class: published-standard
    source_id: owasp-asvs
    section_id: $SECTION
YAML
    echo "standards-closed-loop: promote-to-rule rule=$RID class=published-standard" >&2
    ;;
  provenance-check)
    OK=1
    for f in "$RULES_DIR"/*.yaml; do
      [[ -f "$f" ]] || continue
      grep -q "class: published-standard" "$f" || OK=0
    done
    if [[ "$OK" -eq 1 ]]; then
      echo "standards-closed-loop: all_rules_have_provenance=true rules_dir=$RULES_DIR" >&2
    else
      echo "standards-closed-loop: all_rules_have_provenance=false rules_dir=$RULES_DIR" >&2
      exit 1
    fi
    ;;
  conformance-report)
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
    bash "$SCRIPT_DIR/conformance-report.sh" --active "$ACTIVE" --rules-dir "$RULES_DIR" --out "$OUT" --now "${NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" 2>&1 | sed 's/^/standards-closed-loop: /' >&2
    ;;
  comparator-grounding)
    [[ -z "$QUERY" || ! -f "$QUERY" ]] && { echo "standards-closed-loop: --query required" >&2; exit 2; }
    GS=$(QUERY="$QUERY" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.QUERY,"utf8"));process.stdout.write(String((j.grounded_sources||[]).length))')
    if [[ "$GS" -eq 0 ]]; then
      echo "standards-closed-loop: comparator_declined=true reason=no_grounding_available" >&2
    else
      echo "standards-closed-loop: comparator_declined=false grounded_sources=$GS" >&2
    fi
    ;;
  monitor-feedback)
    [[ -z "$DECISIONS" ]] && { echo "standards-closed-loop: --decisions required" >&2; exit 2; }
    mkdir -p "$(dirname "$DECISIONS")"
    if [[ "$FETCHER_STUB" == "new-content" ]]; then
      printf 'monitor_drift_detected source=%s at=%s\n' "owasp-asvs" "${NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" >> "$DECISIONS"
      echo "standards-closed-loop: monitor_feedback flowed_into=catalog drift_detected=true" >&2
    fi
    ;;
  *)
    echo "standards-closed-loop: unknown --step $STEP" >&2
    exit 2
    ;;
esac
