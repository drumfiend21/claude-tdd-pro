#!/usr/bin/env bash
# L-15 emit a rubric action card with cross-loop origin tag for pr-corpus rules.
set -uo pipefail
RULE=""; EMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: cross-loop-action-card.sh --rule <yaml> [--emit card]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$RULE" || ! -f "$RULE" ]] && { echo "cross-loop-action-card: --rule <yaml> required" >&2; exit 2; }

RULE="$RULE" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
Encoding.default_external = Encoding::UTF_8
data = YAML.unsafe_load_file(ENV["RULE"]) rescue {}
rid = data["rule_id"]
prov = data["provenance"] || []
origin = prov.find { |p| p["class"] }
oc = origin ? origin["class"] : "unknown"
STDERR.puts "cross-loop-action-card: rule_id=#{rid} origin=#{oc}"
'
