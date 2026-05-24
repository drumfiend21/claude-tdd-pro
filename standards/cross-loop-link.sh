#!/usr/bin/env bash
# L-15 standards-loop reads pr-corpus patterns-index for overlap citations.
set -uo pipefail
PATTERNS=""; EMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --patterns) PATTERNS="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: cross-loop-link.sh --patterns <yaml> [--emit links]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$PATTERNS" || ! -f "$PATTERNS" ]] && { echo "cross-loop-link: --patterns <yaml> required" >&2; exit 2; }

PATTERNS="$PATTERNS" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
Encoding.default_external = Encoding::UTF_8
data = YAML.unsafe_load_file(ENV["PATTERNS"]) rescue {}
(data["patterns"] || []).each do |p|
  if p["overlaps_standard"]
    STDERR.puts "cross-loop-link: standard=#{p["overlaps_standard"]} pr_corpus_pattern=#{p["id"]}"
  end
end
'
