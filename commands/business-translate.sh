#!/usr/bin/env bash
# commands/business-translate.sh - S-33 business-to-technical translation
# (v1.13 §27.15).
#
# Maps a business-profile.json (from S-32) to pillar-keyed TECHNICAL concerns,
# each grounded in a catalog source. This is the bridge that turns a beginner's
# business answers ("mission-critical, can only be down minutes, regulated
# HIPAA data") into the technical requirements the S-26 review / S-29 build
# stages consume ("reliability: multi_az + automated_failover; security:
# encryption_at_rest + audit_logging"). The mapping is grounded in the AWS
# Well-Architected pillars (esp. the Reliability Pillar + RPO/RTO guidance) and
# NIST SP 800-53; cite-or-decline holds (an unbacked concern is needs_grounding).
#
# CLI:
#   --profile <json>      business-profile.json from S-32 (required)
#   --out <json>          technical-requirements.json
#                         (default standards/technical-requirements.json)
#   --catalog <path>      S-23 catalog (for grounding verification)
#   --eng-catalog <path>  S-30/S-31 catalog (for grounding verification)
#   --now <iso>           generated_at (default current UTC)
#   --dry-run             preview to stderr; write nothing (§2.14)
#
# stderr: technical_requirements=<path> concerns=<n> pillars=<csv>
#         reliability_concerns=<n> security_concerns=<n> needs_grounding=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

PROFILE=""; OUT=""; CATALOG=""; ENG=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     PROFILE="${2-}"; shift 2 ;;
    --out)         OUT="${2-}";     shift 2 ;;
    --catalog)     CATALOG="${2-}"; shift 2 ;;
    --eng-catalog) ENG="${2-}";     shift 2 ;;
    --now)         NOW="${2-}";     shift 2 ;;
    --dry-run)     DRY_RUN=1;       shift ;;
    -h|--help) echo "Usage: business-translate.sh --profile <json> [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "business-translate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$PROFILE" ]; then echo "business-translate: --profile <json> is required" >&2; exit 2; fi
if [ ! -f "$PROFILE" ]; then echo "business-translate: profile not found: $PROFILE" >&2; exit 2; fi
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ -z "$ENG" ]; then ENG="standards/cloud-engineering-sources.yaml"; fi
CATALOG=$(resolve "$CATALOG"); ENG=$(resolve "$ENG")
if [ -z "$OUT" ]; then OUT="standards/technical-requirements.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

PROFILE="$PROFILE" OUT="$OUT" CATALOG="$CATALOG" ENG="$ENG" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  profile=ENV["PROFILE"]; out=ENV["OUT"]; catalog=ENV["CATALOG"]; eng=ENV["ENG"]
  now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  prof = JSON.parse(File.read(profile))
  a = prof["answers"] || {}

  concerns = []  # {pillar, concern, driver, source_id}
  add = lambda { |pillar, concern, driver, src| concerns << {"pillar"=>pillar, "concern"=>concern, "driver"=>driver, "source_id"=>src} }

  # Reliability from criticality (AWS Reliability Pillar).
  if a["criticality"] == "mission-critical"
    add.call("reliability", "multi_az",           "criticality=mission-critical", "aws-reliability-pillar")
    add.call("reliability", "automated_failover", "criticality=mission-critical", "aws-reliability-pillar")
    add.call("reliability", "health_check",       "criticality=mission-critical", "aws-reliability-pillar")
  end
  # Reliability from availability tolerance / RTO (AWS RPO/RTO guidance).
  case a["availability_tolerance"]
  when "none", "minutes"
    add.call("reliability", "multi_az",           "availability_tolerance=#{a["availability_tolerance"]}", "aws-rpo-rto-targets")
    add.call("reliability", "automated_failover", "availability_tolerance=#{a["availability_tolerance"]}", "aws-rpo-rto-targets")
  when "hours"
    add.call("reliability", "health_check", "availability_tolerance=hours", "aws-rpo-rto-targets")
    add.call("reliability", "backup",       "availability_tolerance=hours", "aws-rpo-rto-targets")
  when "days"
    add.call("reliability", "backup", "availability_tolerance=days", "aws-rpo-rto-targets")
  end
  # Reliability from data-loss tolerance / RPO.
  case a["data_loss_tolerance"]
  when "none", "seconds"
    add.call("reliability", "synchronous_replication", "data_loss_tolerance=#{a["data_loss_tolerance"]}", "aws-rpo-rto-targets")
    add.call("reliability", "point_in_time_recovery",  "data_loss_tolerance=#{a["data_loss_tolerance"]}", "aws-rpo-rto-targets")
  when "minutes"
    add.call("reliability", "frequent_backup", "data_loss_tolerance=minutes", "aws-rpo-rto-targets")
  when "hours"
    add.call("reliability", "daily_backup", "data_loss_tolerance=hours", "aws-rpo-rto-targets")
  end
  # Security from data sensitivity (NIST 800-53).
  if %w[regulated confidential].include?(a["data_sensitivity"])
    add.call("security", "encryption_at_rest",    "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
    add.call("security", "encryption_in_transit", "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
    add.call("security", "access_control",        "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
  end
  # Security from compliance regime (NIST 800-53; DoD SCCA for IL/FedRAMP).
  cr = a["compliance_regime"].to_s
  if !cr.empty? && cr != "none"
    add.call("security", "audit_logging",     "compliance_regime=#{cr}", "nist-800-53")
    add.call("security", "encryption_at_rest","compliance_regime=#{cr}", "nist-800-53")
    if %w[il4 il5 fedramp].include?(cr)
      add.call("security", "boundary_protection", "compliance_regime=#{cr}", "aws-dod-scca-prescriptive")
    end
  end
  # Performance from scale (AWS Well-Architected).
  if %w[large hyperscale].include?(a["scale"])
    add.call("performance-efficiency", "autoscaling", "scale=#{a["scale"]}", "aws-well-architected")
    add.call("performance-efficiency", "caching",     "scale=#{a["scale"]}", "aws-well-architected")
  end
  # Cost from budget posture (FinOps).
  if a["budget_posture"] == "cost-first"
    add.call("cost-optimization", "rightsizing",      "budget_posture=cost-first", "finops-framework")
    add.call("cost-optimization", "managed_services", "budget_posture=cost-first", "finops-framework")
  end
  # Operational-excellence baseline (Google SRE).
  add.call("operational-excellence", "monitoring", "baseline", "google-sre-book")

  # S-39 data + distributed concerns (grounded in the S-37 catalogs); fire only
  # when the --with-data intake answers are present.
  case a["consistency_need"]
  when "strong"
    add.call("data", "strong_consistency",      "consistency_need=strong",   "patterns-of-distributed-systems")
    add.call("data", "synchronous_replication", "consistency_need=strong",   "patterns-of-distributed-systems")
  when "eventual"
    add.call("data", "eventual_consistency",    "consistency_need=eventual", "patterns-of-distributed-systems")
  end
  if %w[large very-large].include?(a["data_volume"])
    add.call("data", "partitioning", "data_volume=#{a["data_volume"]}", "azure-data-store-models")
    add.call("data", "sharding",     "data_volume=#{a["data_volume"]}", "azure-data-store-models")
  end
  if a["read_write_pattern"] == "analytics"
    add.call("data", "data_warehouse", "read_write_pattern=analytics", "aws-data-analytics-lens")
  end
  case a["communication_style"]
  when "event-driven"
    add.call("integration", "message_queue",     "communication_style=event-driven", "enterprise-integration-patterns")
    add.call("integration", "dead_letter_queue", "communication_style=event-driven", "enterprise-integration-patterns")
    add.call("integration", "outbox_pattern",    "communication_style=event-driven", "enterprise-integration-patterns")
  when "synchronous"
    add.call("integration", "api_gateway", "communication_style=synchronous", "enterprise-integration-patterns")
  end
  if %w[external-partner public].include?(a["integration_scope"])
    add.call("integration", "anti_corruption_layer", "integration_scope=#{a["integration_scope"]}", "enterprise-integration-patterns")
    add.call("integration", "contract_test",         "integration_scope=#{a["integration_scope"]}", "enterprise-integration-patterns")
  end
  if a["read_write_pattern"] == "analytics" && a["consistency_need"] == "mixed"
    add.call("distributed", "cqrs", "analytics+mixed-consistency", "fowler-cqrs")
  end
  if a["communication_style"] == "event-driven" && a["criticality"] == "mission-critical"
    add.call("distributed", "saga",           "event-driven+mission-critical", "fowler-event-sourcing")
    add.call("distributed", "event_sourcing", "event-driven+mission-critical", "fowler-event-sourcing")
  end

  # Dedupe by (pillar, concern); first driver/source wins.
  seen = {}; deduped = []
  concerns.each do |c|
    k = "#{c["pillar"]}:#{c["concern"]}"
    next if seen[k]
    seen[k] = true; deduped << c
  end

  # Grounding verification (cite-or-decline): a concern whose source is in no
  # catalog is marked needs_grounding.
  grounded = {}
  sdir = File.dirname(catalog)
  [catalog, eng, File.join(sdir, "data-architecture-sources.yaml"), File.join(sdir, "distributed-systems-sources.yaml")].each do |cf|
    next unless File.exist?(cf)
    d = begin; YAML.unsafe_load_file(cf); rescue; nil; end
    next unless d.is_a?(Array)
    d.each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end
  needs = []
  deduped.each do |c|
    unless grounded[c["source_id"]]
      c["grounding"] = "needs_grounding"; needs << c["concern"]
    else
      c["grounding"] = "grounded"
    end
  end

  by_pillar = {}
  deduped.each { |c| (by_pillar[c["pillar"]] ||= []) << {"concern"=>c["concern"], "driver"=>c["driver"], "source_id"=>c["source_id"], "grounding"=>c["grounding"]} }

  doc = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "concerns_total" => deduped.length,
    "needs_grounding"=> needs.uniq,
    "pillars"        => by_pillar
  }

  unless dry
    require "fileutils"
    dd = File.dirname(out); FileUtils.mkdir_p(dd) unless dd.empty? || dd == "."
    File.write(out, JSON.pretty_generate(doc) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "technical_requirements=#{out}"
  STDERR.puts "concerns=#{deduped.length}"
  STDERR.puts "pillars=#{by_pillar.keys.sort.join(",")}"
  STDERR.puts "reliability_concerns=#{(by_pillar["reliability"]||[]).length}"
  STDERR.puts "security_concerns=#{(by_pillar["security"]||[]).length}"
  STDERR.puts "needs_grounding=#{needs.uniq.length}"
'
exit $?
