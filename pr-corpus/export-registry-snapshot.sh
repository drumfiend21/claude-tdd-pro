#!/usr/bin/env bash
# L-17 exports a timestamped snapshot of the active registry to compliance evidence.
set -uo pipefail
REG=""; OUT=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REG="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: export-registry-snapshot.sh --registry <yaml> --out <yaml> [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REG" || ! -f "$REG" ]] && { echo "export-registry-snapshot: --registry <yaml> required" >&2; exit 2; }
[[ -z "$OUT" ]] && { echo "export-registry-snapshot: --out <yaml> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p "$(dirname "$OUT")"
{
  echo "snapshot_at: $NOW"
  cat "$REG"
} > "$OUT"
echo "export-registry-snapshot: written=$OUT snapshot_at=$NOW" >&2
