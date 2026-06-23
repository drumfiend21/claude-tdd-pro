#!/usr/bin/env bash
# commands/migrate-rules-to-applies-to.sh — ADR-0008 Wave 2 parity migration.
#
# Migrates every rule in generated-code-quality-standards/ to the 4-axis canonical vocabulary
# so the composite engine can route the existing corpus to FOSS tools. ADDITIVE + idempotent:
# for each rule it sets
#   applies_to  := the namespace's 4-axis binding (standards/namespace-axis-binding.yaml)
#   enforced_by := [ {tool: <the rule's EXISTING detector>, required: true},   # parity: never dropped
#                    {tool: <each FOSS tool for the namespace>},               # new composite routing
#                    {bundle: architectural-content} if applies_to_prose ]     # §28.24 auto-bind
# Every other field (detector, severity, provenance, ...) is preserved byte-for-byte. Re-running
# is a no-op (skips a rule already carrying a 4-axis applies_to object whose binding matches).
#
# CLI: [--root <dir>] [--dry-run]   exit 0 ok / 2 usage.

set -uo pipefail
ROOT=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: migrate-rules-to-applies-to.sh [--root <dir>] [--dry-run]" >&2; exit 0 ;;
    *) echo "migrate-rules-to-applies-to: unknown arg: $1" >&2; exit 2 ;;
  esac
done
# --root is the RULES tree to migrate; the binding map is PLUGIN substrate (lives in the
# plugin tree), so it is resolved from CLAUDE_PLUGIN_ROOT — not --root — which lets a generator
# migrate a freshly-generated tree (e.g. --root t) using the real plugin's map.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$ROOT" ] && ROOT="$PLUGIN_ROOT"
MAP="$PLUGIN_ROOT/standards/namespace-axis-binding.yaml"
[ -f "$MAP" ] || { echo "migrate-rules-to-applies-to: binding map missing: $MAP" >&2; exit 2; }

ROOT="$ROOT" MAP="$MAP" DRY="$DRY" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]; dry = ENV["DRY"] == "1"
  cfg = YAML.unsafe_load_file(ENV["MAP"]) rescue {}
  default = cfg["default"] || {}
  binds = cfg["namespaces"] || {}

  migrated = 0; files = 0; skipped = 0
  Dir[File.join(root, "generated-code-quality-standards", "*", "*.yaml")].sort.each do |f|
    ns = f.split("/")[-2]
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    rules = d["rules"]; next unless rules.is_a?(Array) && !rules.empty?
    b = binds[ns] || default
    ling = Array(b["linguist_aliases"]); iac = Array(b["iac_dialects"]); foss = Array(b["foss_tools"])

    changed = false
    rules.each do |r|
      next unless r.is_a?(Hash) && r["id"]
      # desired applies_to (4-axis object). Only include non-empty axes. dup arrays so
      # Psych does not emit shared YAML anchors (each rule gets distinct array objects).
      axis = {}
      axis["linguist_aliases"] = ling.map(&:dup) unless ling.empty?
      axis["iac_dialects"] = iac.map(&:dup) unless iac.empty?
      # desired enforced_by: existing detector first (parity), then FOSS tools, then bundle.
      eb = []
      eb << { "tool" => r["detector"], "required" => true } if r["detector"]
      foss.each { |t| eb << { "tool" => t } }
      eb << { "bundle" => "architectural-content" } if r["applies_to_prose"] == true

      # Consumer Compatibility Contract (§28.40): the introduced_in epoch tag. Existing
      # (pre-contract) rules => "baseline" (grandfathered); new rules carry their introducing pin
      # set in the generator catalog. The tag lets consumers gate enforcement floors by epoch.
      need_epoch = r["introduced_in"].to_s.empty?

      if r["applies_to"] == (axis.empty? ? nil : axis) && r["enforced_by"] == eb && !need_epoch
        next   # idempotent: already migrated to the current binding + already epoch-tagged
      end
      r["applies_to"] = axis unless axis.empty?
      r["enforced_by"] = eb
      # assigned LAST so field order is identical whether the rule is freshly generated or
      # re-migrated (keeps generator output byte-deterministic).
      r["introduced_in"] = "baseline" if need_epoch
      changed = true
    end

    files += 1
    if changed
      migrated += rules.size
      File.write(f, d.to_yaml) unless dry
    else
      skipped += 1
    end
  end
  STDERR.puts "migrate-rules-to-applies-to: files=#{files} migrated_rules=#{migrated} unchanged_files=#{skipped} dry_run=#{dry}"
'
