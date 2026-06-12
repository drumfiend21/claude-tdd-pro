#!/usr/bin/env bash
# commands/architect-recommend.sh - S-34 multi-option recommendation composer
# (v1.13 §27.15; option-composer design §27.16; objectives §27.17).
#
# The creative "option composer": reads the S-33 technical-requirements (and
# optionally the S-32 business-profile) and composes 2-4 distinct, grounded
# architecture OPTIONS, each with explicit trade-offs, the business drivers
# behind it, a suggested ADR title (-> S-28), and build requirements (-> S-29).
# This improves on a single prioritized findings list: the beginner gets
# several creative-but-grounded paths and can choose. Security/compliance
# concerns appear in EVERY option (non-negotiable). cite-or-decline: an option
# with no grounded concern is marked needs_grounding.
#
# CLI:
#   --requirements <json>   S-33 technical-requirements.json (required)
#   --profile <json>        S-32 business-profile.json (optional; drivers + pick)
#   --out <json>            options output (default standards/architecture-options.json)
#   --max-options <N>       clamp option count to 2..4 (default: 3, or 4 if mission-critical)
#   --emit-adr-args <id>    print S-28 cloud-adr.sh args for an option; no file write
#   --emit-requirements <id> print S-29 build requirements (csv) for an option; no file write
#   --now <iso>             generated_at (default current UTC)
#   --dry-run               preview to stderr; write nothing (S2.14)
#
# stderr: options=<path> option_count=<n> recommended=<id> needs_grounding=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

REQ=""; PROFILE=""; OUT=""; MAXOPT=""; EMIT_ADR=""; EMIT_REQ=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --requirements)     REQ="${2-}";      shift 2 ;;
    --profile)          PROFILE="${2-}";  shift 2 ;;
    --out)              OUT="${2-}";       shift 2 ;;
    --max-options)      MAXOPT="${2-}";    shift 2 ;;
    --emit-adr-args)    EMIT_ADR="${2-}";  shift 2 ;;
    --emit-requirements) EMIT_REQ="${2-}"; shift 2 ;;
    --now)              NOW="${2-}";       shift 2 ;;
    --dry-run)          DRY_RUN=1;         shift ;;
    -h|--help) echo "Usage: architect-recommend.sh --requirements <json> [--profile <json>] [--out <path>] [--max-options N] [--emit-adr-args <id>] [--emit-requirements <id>] [--dry-run]" >&2; exit 0 ;;
    *) echo "architect-recommend: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$REQ" ]; then echo "architect-recommend: --requirements <json> is required" >&2; exit 2; fi
if [ ! -f "$REQ" ]; then echo "architect-recommend: requirements not found: $REQ" >&2; exit 2; fi
if [ -z "$OUT" ]; then OUT="standards/architecture-options.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

REQ="$REQ" PROFILE="$PROFILE" OUT="$OUT" MAXOPT="$MAXOPT" EMIT_ADR="$EMIT_ADR" \
EMIT_REQ="$EMIT_REQ" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  req=ENV["REQ"]; profile=ENV["PROFILE"]; out=ENV["OUT"]; maxopt=ENV["MAXOPT"]
  emit_adr=ENV["EMIT_ADR"]; emit_req=ENV["EMIT_REQ"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  reqs = JSON.parse(File.read(req))
  pil  = reqs["pillars"] || {}
  prof = (!profile.empty? && File.exist?(profile)) ? JSON.parse(File.read(profile)) : nil
  ans  = (prof && prof["answers"]) || {}
  workload = ans["workload"] || "the workload"
  criticality = ans["criticality"]
  budget = ans["budget_posture"]

  sec  = pil["security"] || []
  rel  = pil["reliability"] || []
  perf = pil["performance-efficiency"] || []
  cost = pil["cost-optimization"] || []
  ops  = pil["operational-excellence"] || []

  names = lambda { |list| list.map { |c| c["concern"] } }
  light_rel = rel.select { |c| %w[backup daily_backup frequent_backup health_check].include?(c["concern"]) }

  make = lambda do |id, summary, posture, concerns, trade_offs|
    concerns = concerns.uniq { |c| c["concern"] }
    {
      "option_id"        => id,
      "summary"          => summary,
      "posture"          => posture,
      "patterns"         => names.call(concerns),
      "pillar_coverage"  => concerns.map { |c| c["pillar"] || nil }.compact.uniq,
      "trade_offs"       => trade_offs,
      "drivers"          => concerns.map { |c| c["driver"] }.compact.uniq,
      "grounding"        => concerns.map { |c| c["source_id"] }.compact.uniq.sort,
      "suggested_adr_title" => "Adopt #{summary.downcase} for #{workload}",
      "build_requirements"  => names.call(concerns)
    }
  end
  # carry pillar onto each concern for coverage
  sec.each { |c| c["pillar"] ||= "security" }; rel.each { |c| c["pillar"] ||= "reliability" }
  perf.each { |c| c["pillar"] ||= "performance-efficiency" }; cost.each { |c| c["pillar"] ||= "cost-optimization" }
  ops.each { |c| c["pillar"] ||= "operational-excellence" }

  options = []
  options << make.call("opt-cost", "Cost-optimized managed baseline", "managed-simple",
    sec + light_rel + cost + ops,
    {"cost"=>"low","complexity"=>"low","performance"=>"medium","availability"=>"medium","vendor_lock_in"=>"medium"})
  options << make.call("opt-balanced", "Balanced hybrid", "balanced-hybrid",
    sec + (rel.reject { |c| c["concern"] == "synchronous_replication" }) + perf + cost + ops,
    {"cost"=>"medium","complexity"=>"medium","performance"=>"medium","availability"=>"high","vendor_lock_in"=>"low"})
  options << make.call("opt-resilient", "Resilient scale-out", "scale-out",
    sec + rel + perf + ops,
    {"cost"=>"high","complexity"=>"high","performance"=>"high","availability"=>"high","vendor_lock_in"=>"medium"})
  if criticality == "mission-critical"
    options << make.call("opt-max", "Maximum-resilience multi-region", "max-resilience",
      sec + rel + perf + ops,
      {"cost"=>"high","complexity"=>"high","performance"=>"high","availability"=>"very-high","vendor_lock_in"=>"medium"})
  end

  # Clamp count to 2..4.
  natural = options.length
  n = maxopt.empty? ? natural : maxopt.to_i
  n = 2 if n < 2
  n = 4 if n > 4
  n = natural if n > natural
  options = options[0, n]

  needs = options.select { |o| o["grounding"].empty? }.map { |o| o["option_id"] }

  # Recommended pick (S-46 will score rigorously; this is a sensible default).
  recommended =
    if budget == "cost-first" then "opt-cost"
    elsif budget == "uptime-first" then (options.any? { |o| o["option_id"] == "opt-max" } ? "opt-max" : "opt-resilient")
    else "opt-balanced" end
  recommended = options.first["option_id"] unless options.any? { |o| o["option_id"] == recommended }

  by_id = {}; options.each { |o| by_id[o["option_id"]] = o }

  # Integration emitters (no file write).
  unless emit_adr.empty?
    o = by_id[emit_adr]
    if o.nil?; STDERR.puts "architect-recommend: no option #{emit_adr}"; exit 2; end
    primary = o["pillar_coverage"].first || "reliability"
    others = options.reject { |x| x["option_id"] == o["option_id"] }.map { |x| x["summary"] }.join(", ")
    rationale = o["drivers"].join("; ")
    STDOUT.puts "--title \"#{o["suggested_adr_title"]}\" --pillar #{primary} --decision \"#{o["summary"]}\" --options \"#{others}\" --rationale \"#{rationale}\""
    exit 0
  end
  unless emit_req.empty?
    o = by_id[emit_req]
    if o.nil?; STDERR.puts "architect-recommend: no option #{emit_req}"; exit 2; end
    STDOUT.puts o["build_requirements"].join(",")
    exit 0
  end

  doc = {
    "schema_version"        => "1.0",
    "generated_at"          => now,
    "option_count"          => options.length,
    "recommended_option_id" => recommended,
    "needs_grounding"       => needs,
    "options"               => options
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(doc) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "options=#{out}"
  STDERR.puts "option_count=#{options.length}"
  STDERR.puts "recommended=#{recommended}"
  STDERR.puts "needs_grounding=#{needs.length}"
'
exit $?
