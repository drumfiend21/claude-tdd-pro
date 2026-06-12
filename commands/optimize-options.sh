#!/usr/bin/env bash
# commands/optimize-options.sh - S-46 objective-weighted optimization & option
# scoring (v1.15 §27.17; weighting requirement §27.18).
#
# Scores and ranks the S-34 architecture options against FOUR grounded
# objectives so the recommendation is first-class (weighed across all four, not
# chosen on one): cost-effective (finops-framework + AWS WAF Cost pillar),
# performance-optimized (AWS WAF Performance Efficiency), customer-centric
# (aws-reliability-pillar), shareholder-centric (google-eng-practices +
# finops). Weights derive from the business-profile and are overridable. Emits
# a ranked option-scoring.json with per-objective scores + grounded rationale.
# cite-or-decline: an objective whose source is in no catalog is needs_grounding.
#
# CLI:
#   --options <json>     S-34 architecture-options.json (required)
#   --profile <json>     S-32 business-profile.json (optional; derives weights)
#   --weights <csv>      override: cost=..,performance=..,customer=..,shareholder=..
#   --out <json>         output (default standards/option-scoring.json)
#   --now <iso>          generated_at (default current UTC)
#   --dry-run            preview to stderr; write nothing (S2.14)
#
# stderr: scoring=<path> recommended=<id> ranked=<csv> weights=<...>
#         needs_grounding=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

OPTS=""; PROFILE=""; WEIGHTS=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --options) OPTS="${2-}";    shift 2 ;;
    --profile) PROFILE="${2-}"; shift 2 ;;
    --weights) WEIGHTS="${2-}"; shift 2 ;;
    --out)     OUT="${2-}";     shift 2 ;;
    --now)     NOW="${2-}";     shift 2 ;;
    --dry-run) DRY_RUN=1;       shift ;;
    -h|--help) echo "Usage: optimize-options.sh --options <json> [--profile <json>] [--weights <csv>] [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "optimize-options: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OPTS" ]; then echo "optimize-options: --options <json> is required" >&2; exit 2; fi
if [ ! -f "$OPTS" ]; then echo "optimize-options: options not found: $OPTS" >&2; exit 2; fi
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
CATALOG=$(resolve "standards/cloud-architecture-sources.yaml")
ENG=$(resolve "standards/cloud-engineering-sources.yaml")
if [ -z "$OUT" ]; then OUT="standards/option-scoring.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

OPTS="$OPTS" PROFILE="$PROFILE" WEIGHTS="$WEIGHTS" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" \
CATALOG="$CATALOG" ENG="$ENG" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  optf=ENV["OPTS"]; profile=ENV["PROFILE"]; weights=ENV["WEIGHTS"]; out=ENV["OUT"]
  now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"; catalog=ENV["CATALOG"]; eng=ENV["ENG"]

  doc = JSON.parse(File.read(optf))
  options = doc["options"] || []
  prof = (!profile.empty? && File.exist?(profile)) ? JSON.parse(File.read(profile)) : nil
  ans = (prof && prof["answers"]) || {}

  # Objective -> grounding source (the four objectives, each grounded).
  OBJ_SRC = {
    "cost_effective"        => "finops-framework",
    "performance_optimized" => "aws-well-architected",
    "customer_centric"      => "aws-reliability-pillar",
    "shareholder_centric"   => "google-eng-practices"
  }
  OBJ_RATIONALE = {
    "cost_effective"        => "scored on the cost trade-off; lower spend is more cost-effective (FinOps + AWS WAF Cost Optimization)",
    "performance_optimized" => "scored on the performance trade-off (AWS WAF Performance Efficiency)",
    "customer_centric"      => "scored on availability/uptime, which customers feel directly (AWS Reliability Pillar)",
    "shareholder_centric"   => "scored on cost efficiency, low maintenance complexity, and low vendor lock-in (Google Eng Practices + FinOps)"
  }

  # Qualitative level -> score.
  cost_s = {"low"=>1.0,"medium"=>0.6,"high"=>0.3,"very-high"=>0.1}
  perf_s = {"low"=>0.3,"medium"=>0.6,"high"=>0.9,"very-high"=>1.0}
  avail_s= {"low"=>0.3,"medium"=>0.5,"high"=>0.85,"very-high"=>1.0}
  cplx_s = {"low"=>1.0,"medium"=>0.6,"high"=>0.3,"very-high"=>0.1}
  lock_s = {"low"=>1.0,"medium"=>0.6,"high"=>0.3,"very-high"=>0.1}
  g = lambda { |m,k| m[k.to_s] || 0.5 }

  # Weights: profile-derived presets, overridable. All four always present.
  w = {"cost_effective"=>0.25,"performance_optimized"=>0.25,"customer_centric"=>0.25,"shareholder_centric"=>0.25}
  case ans["budget_posture"]
  when "cost-first"   then w = {"cost_effective"=>0.40,"performance_optimized"=>0.20,"customer_centric"=>0.20,"shareholder_centric"=>0.20}
  when "uptime-first" then w = {"cost_effective"=>0.15,"performance_optimized"=>0.25,"customer_centric"=>0.45,"shareholder_centric"=>0.15}
  else
    if ans["criticality"] == "mission-critical"
      w = {"cost_effective"=>0.20,"performance_optimized"=>0.20,"customer_centric"=>0.40,"shareholder_centric"=>0.20}
    end
  end
  unless weights.empty?
    weights.split(",").each do |kv|
      k, _, v = kv.partition("=")
      key = {"cost"=>"cost_effective","performance"=>"performance_optimized","customer"=>"customer_centric","shareholder"=>"shareholder_centric"}[k.strip] || k.strip
      w[key] = v.to_f if w.key?(key)
    end
  end

  scored = options.map do |o|
    to = o["trade_offs"] || {}
    s = {
      "cost_effective"        => g.call(cost_s,  to["cost"]),
      "performance_optimized" => g.call(perf_s,  to["performance"]),
      "customer_centric"      => g.call(avail_s, to["availability"]),
      "shareholder_centric"   => ((g.call(cost_s,to["cost"]) + g.call(cplx_s,to["complexity"]) + g.call(lock_s,to["vendor_lock_in"])) / 3.0)
    }
    total = w.map { |k,wt| wt * s[k] }.inject(0.0, :+)
    {
      "option_id" => o["option_id"],
      "summary"   => o["summary"],
      "scores"    => s.transform_values { |x| (x*1000).round/1000.0 },
      "total_score" => (total*1000).round/1000.0,
      "rationale" => OBJ_RATIONALE
    }
  end
  scored.sort_by! { |x| [-x["total_score"], x["option_id"]] }
  ranked = scored.map { |x| x["option_id"] }
  recommended = ranked.first

  # cite-or-decline: verify each objective source is in a catalog.
  grounded = {}
  [catalog, eng].each do |c|
    next unless File.exist?(c)
    d = begin; YAML.unsafe_load_file(c); rescue; nil; end
    next unless d.is_a?(Array)
    d.each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end
  objectives = OBJ_SRC.map do |obj, src|
    { "objective"=>obj, "source_id"=>src, "grounding"=> (grounded[src] ? "grounded" : "needs_grounding") }
  end
  needs = objectives.select { |o| o["grounding"] == "needs_grounding" }.map { |o| o["objective"] }

  report = {
    "schema_version"        => "1.0",
    "generated_at"          => now,
    "weights"               => w,
    "objectives"            => objectives,
    "needs_grounding"       => needs,
    "ranked"                => ranked,
    "recommended_option_id" => recommended,
    "scored_options"        => scored
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(report) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "scoring=#{out}"
  STDERR.puts "recommended=#{recommended}"
  STDERR.puts "ranked=#{ranked.join(",")}"
  STDERR.puts "weights=cost:#{w["cost_effective"]},perf:#{w["performance_optimized"]},customer:#{w["customer_centric"]},shareholder:#{w["shareholder_centric"]}"
  STDERR.puts "needs_grounding=#{needs.length}"
'
exit $?
