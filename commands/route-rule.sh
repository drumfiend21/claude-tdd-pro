#!/usr/bin/env bash
# commands/route-rule.sh — ADR-0009 stage 3+4: route a classified rule to its enforcement tools.
#
# Reads a classification (classify-rule.sh output) and standards/kind-to-tool-routing.yaml, and
# emits the rule's `enforced_by[]` (ADR-0008 schema): for each matched 4-axis kind, the routed
# FOSS tool(s); and — per ADR-0009 stage 4 — when applies_to_prose is true, the
# architectural-content bundle is auto-attached unconditionally. A rule that classifies to NO
# code-shape kind and is prose-applicable binds solely to the bundle.
#
# CLI: --in <classification-json> [--routing <routing.yaml>] [--json]
# stdout (--json): { enforced_by: [ {tool|bundle, license, required}... ] }
# stderr: `route enforced_by=<csv> bundle=<bool>`
# Exit: 0 ok | 2 usage.

set -uo pipefail
IN=""; ROUTING=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --in)      IN="${2-}"; shift 2 ;;
    --routing) ROUTING="${2-}"; shift 2 ;;
    --json)    JSON=1; shift ;;
    -h|--help) echo "Usage: route-rule.sh --in <classification.json> [--routing <routing.yaml>] [--json]" >&2; exit 0 ;;
    *) echo "route-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$IN" ] && { echo "route-rule: --in <classification.json> required" >&2; exit 2; }
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$ROUTING" ] && ROUTING="$PLUGIN_ROOT/standards/kind-to-tool-routing.yaml"

IN="$IN" ROUTING="$ROUTING" JSON="$JSON" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  cls = JSON.parse(File.read(ENV["IN"])) rescue {}
  routing = YAML.unsafe_load_file(ENV["ROUTING"]) rescue {}
  applies = cls["applies_to"] || {}
  prose = cls["applies_to_prose"] == true

  enforced = []
  seen = {}
  add = lambda do |entry|
    key = entry["tool"] || ("bundle:" + entry["bundle"].to_s)
    return if seen[key]
    seen[key] = true; enforced << entry
  end

  # code-shape kinds -> routed tools (first listed = primary)
  %w[linguist_aliases iac_dialects purl_uses].each do |axis|
    Array(applies[axis]).each do |val|
      Array((routing[axis] || {})[val]).each do |t|
        e = { "tool" => t["tool"], "bundle" => t["bundle"], "license" => t["license"],
              "invoke_only" => t["invoke_only"] }.compact
        add.call(e) unless e.empty?
      end
    end
  end

  # ADR-0009 stage 4: applies_to_prose -> auto-attach the architectural-content bundle
  if prose
    Array(routing["prose"]).each { |b| add.call({ "bundle" => b["bundle"] }.compact) }
  end

  csv = enforced.map { |e| e["tool"] || ("bundle:" + e["bundle"].to_s) }.join(",")
  STDERR.puts "route enforced_by=#{csv} bundle=#{prose}"
  puts JSON.generate({ "enforced_by" => enforced }) if ENV["JSON"] == "1"
'
