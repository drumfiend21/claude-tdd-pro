#!/usr/bin/env bash
# S-9 standards-conformance report generator. Writes
# STANDARDS-CONFORMANCE.md alongside compliance/COMPLIANCE-REPORT.md.
set -uo pipefail
OUT=""; OUT_DIR=""; ACTIVE=""; COVERAGE=""; RULES_DIR=""; NOW=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --active) ACTIVE="$2"; shift 2 ;;
    --coverage) COVERAGE="$2"; shift 2 ;;
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: conformance-report.sh [--out <md> | --out-dir <dir>] [--active <yaml>] [--coverage <json>] [--rules-dir <dir>] [--now <iso>] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ -z "$OUT" && -n "$OUT_DIR" ]] && OUT="$OUT_DIR/STANDARDS-CONFORMANCE.md"
[[ -z "$OUT" ]] && OUT="STANDARDS-CONFORMANCE.md"

if [[ "$DRY" -eq 1 ]]; then
  echo "conformance-report: planned: write STANDARDS-CONFORMANCE.md to $OUT at=$NOW dry_run=true" >&2
  exit 0
fi

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
{
  echo "# Standards Conformance"
  echo ""
  echo "generated_at: $NOW"
  echo ""
  # Source list: prefer --active yaml (block or inline), else fall back to coverage keys.
  SOURCES=""
  if [[ -n "$ACTIVE" && -f "$ACTIVE" ]]; then
    SOURCES=$(grep -E '^[[:space:]]+-[[:space:]]' "$ACTIVE" | sed -E 's/^[[:space:]]+-[[:space:]]*//')
    if [[ -z "$SOURCES" ]]; then
      SOURCES=$(grep -E '^sources:' "$ACTIVE" | head -1 | sed -E 's/sources:[[:space:]]*\[//;s/\][[:space:]]*$//' | tr ',' ' ' | tr -d ' "')
    fi
  fi
  if [[ -z "$SOURCES" && -n "$COVERAGE" && -f "$COVERAGE" ]]; then
    SOURCES=$(COV="$COVERAGE" node -e 'process.stdout.write(Object.keys(JSON.parse(require("fs").readFileSync(process.env.COV,"utf8"))).join(" "))')
  fi
  if [[ -z "$SOURCES" ]]; then
    echo "no_active_standards: true"
  else
    for s in $SOURCES; do
        echo "## $s"
        echo ""
        if [[ -n "$COVERAGE" && -f "$COVERAGE" ]]; then
          PCT=$(COVERAGE="$COVERAGE" SRC="$s" node -e '
            const j = JSON.parse(require("fs").readFileSync(process.env.COVERAGE, "utf8"));
            const e = j[process.env.SRC];
            if (e) {
              const pct = Math.round((e.sections_adopted || 0) / (e.sections_total || 1) * 100);
              process.stdout.write(String(pct));
            }
          ')
          [[ -n "$PCT" ]] && echo "adoption_pct: $PCT"
        fi
        if [[ -n "$RULES_DIR" && -d "$RULES_DIR" ]]; then
          for rf in "$RULES_DIR"/*.yaml; do
            [[ ! -f "$rf" ]] && continue
            if grep -q "source_id: $s" "$rf"; then
              rid=$(grep -E '^rule_id:' "$rf" | head -1 | sed -E 's/rule_id:[[:space:]]*//')
              echo "rule_id: $rid"
            fi
          done
        fi
        echo ""
    done
  fi
} > "$OUT"
echo "conformance-report: wrote $OUT at=$NOW" >&2
