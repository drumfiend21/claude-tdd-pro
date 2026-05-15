#!/usr/bin/env bash
# L-1 default-sources lister.
set -uo pipefail
FORMAT="default"; ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    -h|--help) echo "Usage: list-default-sources.sh [--format default|tier-counts|ids|applies-to-check] [--id <id>]"; exit 0 ;;
    *) shift ;;
  esac
done
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CATALOG="$PLUGIN_ROOT/pr-corpus/sources/PR-SOURCES.defaults.yaml"

CATALOG="$CATALOG" FORMAT="$FORMAT" ID="$ID" ruby -ryaml -e '
d = YAML.load_file(ENV["CATALOG"])
sources = d["sources"]
fmt = ENV["FORMAT"]
target_id = ENV["ID"]

if !target_id.empty?
  s = sources.find { |x| x["id"] == target_id }
  if s
    STDERR.puts "id=#{s["id"]}"
    STDERR.puts "source_class=#{s["source_class"]}"
    STDERR.puts "tier=#{s["tier"]}"
    STDERR.puts "applies_to=#{(s["applies_to"]||[]).join(",")}"
  end
  exit 0
end

case fmt
when "tier-counts"
  t1 = sources.count { |s| s["tier"] == 1 }
  t2 = sources.count { |s| s["tier"] == 2 }
  STDERR.puts "tier_1=#{t1}"
  STDERR.puts "tier_2=#{t2}"
when "ids"
  sources.each { |s| STDERR.puts s["id"] }
when "applies-to-check"
  sources.each { |s| STDERR.puts "id=#{s["id"]} applies_to=#{(s["applies_to"]||[]).join(",")}" }
else
  sources.each do |s|
    STDERR.puts "id=#{s["id"]} class=#{s["source_class"]} tier=#{s["tier"]} applies_to=#{(s["applies_to"]||[]).join(",")}"
  end
end
'
