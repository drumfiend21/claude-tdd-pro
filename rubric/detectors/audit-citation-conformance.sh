#!/usr/bin/env bash
# rubric/detectors/audit-citation-conformance.sh - universal citation-conformance
# auditor (§2.33, v1.18 §28.13).
#
# Verifies that EVERY artifact the plugin produces -- full-stack and cloud,
# architecture/design/code -- conforms to cited rules drawn from the plugin's
# authoritative sources, across BOTH source triads:
#   (i)  operator registries: STANDARDS, COMPLIANCE, PR-CORPUS
#   (ii) cloud grounding catalogs: cloud-architecture (S-23), engineering
#        (S-30/S-31), EO-security (S-54)
# cite-or-decline is universal: an artifact citing no grounded source is a
# conformance violation (ungrounded), never silently accepted.
#
# Surfaces audited (statically, over --root):
#   cloud-conventions  every standards/cloud-conventions/*.yaml rule's source_id
#                      is grounded in the union of the three cloud catalogs
#   coding-rules       every generated-code-quality-standards/<ns>/*.yaml rule
#                      (non-empty rules:) carries provenance[] with a source
#   reading-sources    every reading-source file (rules: []) has a source: id header
#   registries         the three operator registries exist and are non-empty
#   cloud-catalogs     the three cloud catalogs exist and are non-empty
#
# CLI: --root <dir> (default $CLAUDE_PLUGIN_ROOT) [--quiet]
# stderr: per-surface `citation-conformance surface=<s> status=<green|red> items=<n> ungrounded=<m>`
#         overall     `citation-conformance status=<green|red> surfaces=<n> ungrounded=<total>`
# Exit: 0 green | 1 red (some artifact ungrounded / a required registry|catalog missing) | 2 usage.

set -uo pipefail

ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: audit-citation-conformance.sh [--root <dir>] [--quiet]" >&2
      exit 0 ;;
    *) echo "audit-citation-conformance: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ]; then ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"; fi
if [ ! -d "$ROOT" ]; then echo "audit-citation-conformance: root not found: $ROOT" >&2; exit 2; fi

ROOT="$ROOT" QUIET="$QUIET" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]; quiet = ENV["QUIET"] == "1"
  red_total = 0; surfaces = 0

  def load_array(f)
    d = (YAML.unsafe_load_file(f) rescue nil)
    return d if d.is_a?(Array)
    return d["sources"] if d.is_a?(Hash) && d["sources"].is_a?(Array)
    nil
  end

  def emit(quiet, s, status, items, ungrounded)
    STDERR.puts "citation-conformance surface=#{s} status=#{status} items=#{items} ungrounded=#{ungrounded}" unless quiet
  end

  # --- surface: cloud-conventions grounded in the 3 cloud catalogs -----------
  cloud_catalogs = %w[
    standards/cloud-architecture-sources.yaml
    standards/cloud-engineering-sources.yaml
    standards/eo-security-sources.yaml
  ].map { |p| File.join(root, p) }
  grounded = {}
  cloud_catalogs.each do |c|
    arr = File.exist?(c) ? load_array(c) : nil
    (arr || []).each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end
  cc_items = 0; cc_bad = 0
  Dir[File.join(root, "standards/cloud-conventions/*.yaml")].sort.each do |rf|
    arr = load_array(rf) || []
    arr.each do |r|
      next unless r.is_a?(Hash) && r["id"]
      cc_items += 1
      cc_bad += 1 unless grounded[r["source_id"]]
    end
  end
  emit(quiet, "cloud-conventions", cc_bad.zero? ? "green" : "red", cc_items, cc_bad)
  red_total += cc_bad; surfaces += 1

  # --- surface: coding rules carry provenance with a source ------------------
  cr_items = 0; cr_bad = 0
  Dir[File.join(root, "generated-code-quality-standards/*/*.yaml")].sort.each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    rules = d["rules"]; next unless rules.is_a?(Array) && !rules.empty?
    rules.each do |r|
      cr_items += 1
      prov = r.is_a?(Hash) ? r["provenance"] : nil
      ok = prov.is_a?(Array) && prov.any? { |p| p.is_a?(Hash) && (p["source"] || p["source_id"]) }
      cr_bad += 1 unless ok
    end
  end
  emit(quiet, "coding-rules", cr_bad.zero? ? "green" : "red", cr_items, cr_bad)
  red_total += cr_bad; surfaces += 1

  # --- surface: reading-sources have a source: id header --------------------
  rs_items = 0; rs_bad = 0
  Dir[File.join(root, "generated-code-quality-standards/*/*.yaml")].sort.each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    next unless d["rules"].is_a?(Array) && d["rules"].empty?
    rs_items += 1
    src = d["source"]
    rs_bad += 1 unless src.is_a?(Hash) && src["id"]
  end
  emit(quiet, "reading-sources", rs_bad.zero? ? "green" : "red", rs_items, rs_bad)
  red_total += rs_bad; surfaces += 1

  # --- surface: the three operator registries present and non-empty ---------
  registries = {
    "standards"  => "standards/sources.yaml",
    "compliance" => ".claude-tdd-pro/COMPLIANCE-URLS.yaml",
    "pr-corpus"  => "pr-corpus/PR-SOURCES-DEFAULT.yaml",
  }
  reg_bad = 0
  registries.each_value do |p|
    f = File.join(root, p)
    arr = File.exist?(f) ? load_array(f) : nil
    has = arr.is_a?(Array) && arr.any? { |e| e.is_a?(Hash) && e["id"] }
    reg_bad += 1 unless has
  end
  emit(quiet, "registries", reg_bad.zero? ? "green" : "red", registries.size, reg_bad)
  red_total += reg_bad; surfaces += 1

  # --- surface: the three cloud catalogs present and non-empty --------------
  cat_bad = 0
  cloud_catalogs.each do |c|
    arr = File.exist?(c) ? load_array(c) : nil
    has = arr.is_a?(Array) && arr.any? { |e| e.is_a?(Hash) && e["id"] }
    cat_bad += 1 unless has
  end
  emit(quiet, "cloud-catalogs", cat_bad.zero? ? "green" : "red", cloud_catalogs.size, cat_bad)
  red_total += cat_bad; surfaces += 1

  status = red_total.zero? ? "green" : "red"
  STDERR.puts "citation-conformance status=#{status} surfaces=#{surfaces} ungrounded=#{red_total}"
  exit(red_total.zero? ? 0 : 1)
'
