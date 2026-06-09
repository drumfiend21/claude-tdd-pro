#!/usr/bin/env bash
# commands/business-intake.sh - S-32 business-language requirements intake
# (v1.13 §27.15).
#
# A structured questionnaire that captures a workload's requirements in
# BUSINESS language and emits a business-profile.json. The question set is the
# senior-architect follow-up list, modelled on the Azure Well-Architected
# "Align technical strategy with business requirements" Listen->Probe->Clarify
# process and the AWS RPO/RTO guidance; each question is grounded in a catalog
# source so the agent can cite why it is asking.
#
# The agent uses --list-questions to know what to ask, collects answers in
# plain language, and replays them via --answer/--answers; the unanswered /
# invalid surfaces tell the agent exactly which follow-ups remain.
#
# CLI:
#   --list-questions        print the question schema (JSON) to stdout; exit 0
#   --answer key=value      provide one answer (repeatable)
#   --answers <json>        provide answers as a JSON object (file or inline)
#   --out <path>            business-profile.json (default standards/business-profile.json)
#   --now <iso>             generated_at (default current UTC)
#   --partial               write the profile even if incomplete
#   --dry-run               preview to stderr; write nothing (§2.14)
#
# stderr: questions=<n> | unanswered=<csv> | invalid=<key> allowed=<csv> |
#         profile=<path> complete=<true|false> grounded_in=<csv>
# Exit: 0 complete (or list/partial/dry-run) / 1 incomplete / 2 invalid answer.

set -uo pipefail

LIST=0; OUT=""; NOW=""; PARTIAL=0; DRY_RUN=0; ANSWERS_JSON=""
ANSWERS_KV=""

while [ $# -gt 0 ]; do
  case "$1" in
    --list-questions) LIST=1; shift ;;
    --answer)  ANSWERS_KV="${ANSWERS_KV}${2-}"$'\n'; shift 2 ;;
    --answers) ANSWERS_JSON="${2-}"; shift 2 ;;
    --out)     OUT="${2-}"; shift 2 ;;
    --now)     NOW="${2-}"; shift 2 ;;
    --partial) PARTIAL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: business-intake.sh [--list-questions] [--answer key=value]... [--answers <json>] [--out <path>] [--partial] [--dry-run]" >&2; exit 0 ;;
    *) echo "business-intake: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OUT" ]; then OUT="standards/business-profile.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

LIST="$LIST" OUT="$OUT" NOW="$NOW" PARTIAL="$PARTIAL" DRY_RUN="$DRY_RUN" \
ANSWERS_JSON="$ANSWERS_JSON" ANSWERS_KV="$ANSWERS_KV" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  list=ENV["LIST"]=="1"; out=ENV["OUT"]; now=ENV["NOW"]
  partial=ENV["PARTIAL"]=="1"; dry=ENV["DRY_RUN"]=="1"

  # Question schema: the grounded senior-architect intake set.
  # type free accepts any non-empty value; type enum validates against allowed.
  Q = [
    {"key"=>"workload",              "type"=>"free", "allowed"=>[],
     "prompt"=>"What is the workload and what business outcome must it deliver?",
     "source_id"=>"azure-waf-business-requirements"},
    {"key"=>"motivation",            "type"=>"enum", "allowed"=>%w[revenue compliance cost-reduction risk-reduction innovation],
     "prompt"=>"Why is this needed - what is the primary business driver?",
     "source_id"=>"azure-waf-business-requirements"},
    {"key"=>"criticality",           "type"=>"enum", "allowed"=>%w[mission-critical important experimental],
     "prompt"=>"How critical is this system to the business?",
     "source_id"=>"aws-rpo-rto-targets"},
    {"key"=>"availability_tolerance","type"=>"enum", "allowed"=>%w[none minutes hours days],
     "prompt"=>"How long can it be down before real business harm? (RTO)",
     "source_id"=>"aws-rpo-rto-targets"},
    {"key"=>"data_loss_tolerance",   "type"=>"enum", "allowed"=>%w[none seconds minutes hours],
     "prompt"=>"How much recent data could you lose without real harm? (RPO)",
     "source_id"=>"aws-rpo-rto-targets"},
    {"key"=>"data_sensitivity",      "type"=>"enum", "allowed"=>%w[public internal confidential regulated],
     "prompt"=>"How sensitive is the data the system handles?",
     "source_id"=>"nist-800-53"},
    {"key"=>"compliance_regime",     "type"=>"enum", "allowed"=>%w[none hipaa pci soc2 fedramp il4 il5 gdpr],
     "prompt"=>"Which compliance regime, if any, applies?",
     "source_id"=>"nist-800-53"},
    {"key"=>"scale",                 "type"=>"enum", "allowed"=>%w[small medium large hyperscale],
     "prompt"=>"What scale of usage do you expect?",
     "source_id"=>"aws-wa-tool-profiles"},
    {"key"=>"budget_posture",        "type"=>"enum", "allowed"=>%w[cost-first balanced uptime-first],
     "prompt"=>"What is your posture on cost versus uptime?",
     "source_id"=>"aws-wa-tool-profiles"}
  ]

  if list
    STDOUT.puts JSON.pretty_generate(Q)
    STDERR.puts "questions=#{Q.length}"
    exit 0
  end

  # Collect answers from --answers <json> then --answer key=value (kv wins).
  answers = {}
  aj = ENV["ANSWERS_JSON"].to_s
  unless aj.empty?
    raw = File.exist?(aj) ? File.read(aj) : aj
    parsed = begin; JSON.parse(raw); rescue; nil; end
    answers.merge!(parsed) if parsed.is_a?(Hash)
  end
  ENV["ANSWERS_KV"].to_s.split("\n").each do |line|
    next if line.strip.empty?
    k, _, v = line.partition("=")
    answers[k.strip] = v.strip
  end

  by_key = {}; Q.each { |q| by_key[q["key"]] = q }

  # Validate.
  answers.each do |k, v|
    q = by_key[k]
    if q.nil?
      STDERR.puts "invalid=#{k} reason=unknown-question"
      exit 2
    end
    if q["type"] == "enum" && !q["allowed"].include?(v)
      STDERR.puts "invalid=#{k} allowed=#{q["allowed"].join(",")}"
      exit 2
    end
    if q["type"] == "free" && v.to_s.strip.empty?
      STDERR.puts "invalid=#{k} reason=empty"
      exit 2
    end
  end

  answered = Q.select { |q| answers.key?(q["key"]) && !answers[q["key"]].to_s.strip.empty? }
  unanswered = Q.reject { |q| answers.key?(q["key"]) && !answers[q["key"]].to_s.strip.empty? }.map { |q| q["key"] }
  complete = unanswered.empty?
  grounded_in = answered.map { |q| q["source_id"] }.uniq.sort

  if !complete && !partial
    STDERR.puts "unanswered=#{unanswered.join(",")}"
    STDERR.puts "complete=false"
    exit 1
  end

  profile = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "complete"       => complete,
    "answers"        => answers,
    "grounded_in"    => grounded_in,
    "unanswered"     => unanswered
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(profile) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "profile=#{out}"
  STDERR.puts "complete=#{complete}"
  STDERR.puts "grounded_in=#{grounded_in.join(",")}"
  STDERR.puts "unanswered=#{unanswered.join(",")}" unless unanswered.empty?
  exit 0
'
exit $?
