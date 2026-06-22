#!/usr/bin/env bash
# commands/classify-rule.sh — ADR-0009 stage 2: classify a candidate rule into the ADR-0008
# 4-axis canonical vocabulary + the applies_to_prose flag.
#
# Tier-1 (this script, deterministic, no model): an inverted keyword index over the rule's
# title + prose. Catches the ~60-70% of rules whose target stack is named explicitly. When no
# axis matches, confidence=low and the rule is flagged for the Tier-2 LLM classifier (out of
# scope for Wave 1) — never silently dropped.
#
# CLI: --title <t> --prose <p> [--json]   (or --in <segment-json-file>)
# stdout (--json): { applies_to: {...}, applies_to_prose: bool, confidence: high|low, signals: [...] }
# stderr: `classify confidence=<c> prose=<bool> axes=<csv>`
# Exit: 0 ok | 2 usage.

set -uo pipefail
TITLE=""; PROSE=""; IN=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="${2-}"; shift 2 ;;
    --prose) PROSE="${2-}"; shift 2 ;;
    --in)    IN="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: classify-rule.sh (--title <t> --prose <p> | --in <segment.json>) [--json]" >&2; exit 0 ;;
    *) echo "classify-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TITLE$PROSE$IN" ] && { echo "classify-rule: --title/--prose or --in required" >&2; exit 2; }

TITLE="$TITLE" PROSE="$PROSE" IN="$IN" JSON="$JSON" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  if !ENV["IN"].to_s.empty?
    seg = JSON.parse(File.read(ENV["IN"])) rescue {}
    seg = seg.first if seg.is_a?(Array)
    title = (seg["title"] || "").to_s; prose = (seg["prose"] || "").to_s
  else
    title = ENV["TITLE"].to_s; prose = ENV["PROSE"].to_s
  end
  hay = (title + "\n" + prose).downcase

  # inverted keyword index: regex -> [axis, value]. Deterministic Tier-1 signals.
  index = [
    [/typescript|tsconfig|\binterface\b|\bnamespace\b|\.ts\b|type annotation/, ["linguist_aliases", "typescript"]],
    [/javascript|\bes6\b|ecmascript|\.js\b/,                                    ["linguist_aliases", "javascript"]],
    [/\bpython\b|pep ?8|\.py\b|pyproject/,                                        ["linguist_aliases", "python"]],
    [/\bgolang\b|\bgo lang\b|\.go\b/,                                             ["linguist_aliases", "go"]],
    [/terraform|\bhcl\b|\.tf\b|resource block/,                                   ["iac_dialects", "terraform"]],
    [/kubernetes|\bk8s\b|\bpod\b|deployment manifest|securitycontext/,            ["iac_dialects", "kubernetes"]],
    [/dockerfile|\bdocker image\b/,                                               ["iac_dialects", "dockerfile"]],
    [/github actions|workflow file|\.github\/workflows/,                          ["iac_dialects", "github_actions"]],
    [/cloudformation|\bcfn\b/,                                                    ["iac_dialects", "cloudformation"]],
    [/helm chart|values\.yaml/,                                                   ["iac_dialects", "helm"]],
    [/openapi|swagger/,                                                           ["iac_dialects", "openapi"]],
    [/\bnpm\b|package\.json|node module/,                                         ["purl_uses", "npm"]],
    [/\bpypi\b|pip install/,                                                      ["purl_uses", "pypi"]],
    [/apps\/v1\/deployment|kind: deployment/,                                     ["k8s_gvks", "apps/v1/Deployment"]],
  ]
  prose_index = /\badr\b|architecture decision|architectural|design doc|design document|rationale|trade-?off|the decision/

  applies = Hash.new { |h, k| h[k] = [] }
  signals = []
  index.each do |re, (axis, val)|
    if hay =~ re
      applies[axis] << val unless applies[axis].include?(val)
      signals << "#{axis}:#{val}"
    end
  end
  applies.each_value(&:uniq!)
  prose_flag = !(hay =~ prose_index).nil?
  signals << "applies_to_prose" if prose_flag

  confidence = (applies.empty? && !prose_flag) ? "low" : "high"
  axes_csv = applies.keys.join(",") + (prose_flag ? (applies.empty? ? "prose" : ",prose") : "")

  result = { "applies_to" => applies, "applies_to_prose" => prose_flag,
             "confidence" => confidence, "signals" => signals,
             "needs_tier2_llm" => (confidence == "low") }
  STDERR.puts "classify confidence=#{confidence} prose=#{prose_flag} axes=#{axes_csv}"
  puts JSON.generate(result) if ENV["JSON"] == "1"
'
