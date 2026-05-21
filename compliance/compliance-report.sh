#!/usr/bin/env bash
# Minimal compliance-report generator (companion to standards/conformance-report.sh
# per S-9 architecture: "STANDARDS-CONFORMANCE.md report alongside COMPLIANCE-REPORT.md").
set -uo pipefail
OUT=""; OUT_DIR=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: compliance-report.sh [--out <md> | --out-dir <dir>] [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ -z "$OUT" && -n "$OUT_DIR" ]] && OUT="$OUT_DIR/COMPLIANCE-REPORT.md"
[[ -z "$OUT" ]] && OUT="COMPLIANCE-REPORT.md"

mkdir -p "$(dirname "$OUT")" 2>/dev/null || true
{
  echo "# Compliance Report"
  echo ""
  echo "generated_at: $NOW"
  echo ""
  echo "(see audit-pack bundle for full per-framework evidence)"
} > "$OUT"
echo "compliance-report: wrote $OUT at=$NOW" >&2
