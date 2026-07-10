#!/usr/bin/env bash
# commands/resolve-technology.sh — S-58 technology resolver (v1.24 §31, Phase 1 family activation).
#
# Resolves a named technology to its canonical 4-axis coordinate + umbrella(s), and returns the EXISTING
# rule namespaces that naming it ACTIVATES (the umbrella's framework-agnostic rules, plus the technology's
# own namespace if one exists). Phase 1: activation of already-scraped rules only — no acquisition.
#
# Resolution is one of (§2.36, cite-or-decline):
#   status=present      — a specific namespace for the technology exists (activated too)
#   status=needs_source — recognized + umbrella-classified, specific ruleset absent (Phase 2 acquires it)
#   status=unresolved   — no registry mapping (declined, never guessed)
#
# CLI:
#   <name>                 the technology (matched case-insensitively against technology + aliases)
#   --registry <yaml>      default standards/technology-umbrella-registry.yaml
#   --json                 print the full resolution JSON to stdout (default: also prints)
#
# stdout: resolution JSON. stderr marker:
#   resolve=<tech> umbrellas=<csv> activated=<csv> status=<present|needs_source|unresolved>
# Exit: 0 resolved/needs_source/unresolved (well-formed) / 2 usage error.

set -uo pipefail

NAME=""; REGISTRY=""; EXPLAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --registry) REGISTRY="${2-}"; shift 2 ;;
    --explain)  EXPLAIN=1; shift ;;
    --json)     shift ;;
    -h|--help)  echo "Usage: resolve-technology.sh <name> [--registry <yaml>]" >&2; exit 0 ;;
    -*)         echo "resolve-technology: unknown arg: $1" >&2; exit 2 ;;
    *)          if [ -z "$NAME" ]; then NAME="$1"; fi; shift ;;
  esac
done
[ -z "$NAME" ] && { echo "resolve-technology: <name> required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
[ -z "$REGISTRY" ] && REGISTRY="standards/technology-umbrella-registry.yaml"
REGISTRY=$(resolve "$REGISTRY")
[ -f "$REGISTRY" ] || { echo "resolve-technology: registry not found: $REGISTRY" >&2; exit 2; }

NAME="$NAME" REGISTRY="$REGISTRY" PLUGIN_ROOT="$PLUGIN_ROOT" EXPLAIN="$EXPLAIN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  reg = YAML.unsafe_load_file(ENV["REGISTRY"]) || {}
  umbrellas = reg["umbrellas"] || {}
  techs = reg["technologies"] || []
  name = ENV["NAME"].to_s.downcase.strip

  # Only EXISTING namespaces may be activated (the "activate existing rules" guarantee).
  valid_ns = Dir.glob(File.join(ENV["PLUGIN_ROOT"].to_s, "generated-code-quality-standards", "*"))
               .select { |p| File.directory?(p) }.map { |p| File.basename(p) }.reject { |n| n.start_with?("_") }

  # Match by technology name or alias (case-insensitive, whole value).
  t = techs.find do |e|
    next false unless e.is_a?(Hash)
    ([e["technology"].to_s.downcase] + (e["aliases"] || []).map { |a| a.to_s.downcase }).include?(name)
  end

  explain = ENV["EXPLAIN"] == "1"
  if t.nil?
    STDOUT.puts JSON.pretty_generate({ "technology" => name, "status" => "unresolved" })
    STDERR.puts "resolve=#{name} umbrellas= activated= status=unresolved"
    STDERR.puts "EXPLAIN: \"#{name}\" is not a technology the plugin recognizes, so no rules can be applied for it. You can map it with a registry PR, or add its namespaces directly with --stack-add." if explain
    exit 0
  end

  umb = (t["umbrellas"] || [])
  # Cross-family union (§31.3 D4): union the activated namespaces across ALL matched umbrellas.
  general = umb.flat_map { |u| (umbrellas[u] || {})["activates"] || [] }.uniq
  general = general.select { |ns| valid_ns.include?(ns) }        # existing rules only
  specific = t["specific_namespace"]
  specific = nil unless specific && valid_ns.include?(specific)
  status = specific ? "present" : "needs_source"
  activated = (general + (specific ? [specific] : [])).uniq.sort

  out = {
    "technology"          => t["technology"],
    "coordinate"          => t["coordinate"],
    "umbrellas"           => umb,
    "activated_namespaces"=> activated,             # EXISTING rules that naming this activates
    "specific"            => { "namespace" => specific, "status" => status }
  }
  STDOUT.puts JSON.pretty_generate(out)
  STDERR.puts "resolve=#{t["technology"]} umbrellas=#{umb.join(",")} activated=#{activated.join(",")} status=#{status}"
  if explain
    fam = umb.join(" and ")
    if status == "present"
      STDERR.puts "EXPLAIN: #{t["technology"]} is a #{fam} technology with its own ruleset (the \"#{specific}\" namespace), plus the shared #{fam} rules: #{(activated - [specific]).join(", ")}. Naming it turns all of those on."
    else
      STDERR.puts "EXPLAIN: #{t["technology"]} is a #{fam} technology. It has no rules of its own yet, so naming it turns on the shared #{fam} rules (#{activated.join(", ")}); its own rules can be acquired from your sources into a per-project set."
    end
  end
'
exit $?
