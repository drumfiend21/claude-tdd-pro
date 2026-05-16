#!/usr/bin/env bash
# L-17 lists sources with enabled != false (default true).
set -uo pipefail
REG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REG="$2"; shift 2 ;;
    -h|--help) echo "Usage: list-active-sources.sh --registry <yaml>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REG" || ! -f "$REG" ]] && { echo "list-active-sources: --registry <yaml> required" >&2; exit 2; }

REG="$REG" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
Encoding.default_external = Encoding::UTF_8
data = YAML.load_file(ENV["REG"]) rescue {}
sources = (data["sources"] || [])
active = sources.select { |s| s["enabled"] != false }
active.each { |s| STDERR.puts "list-active-sources: id=#{s["id"]} enabled=true" }
STDERR.puts "list-active-sources: active_count=#{active.length} total=#{sources.length}"
'
