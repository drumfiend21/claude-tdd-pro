#!/usr/bin/env bash
# commands/platform-boundary.sh - S-41 platform-boundary contract & dispatcher
# (v1.14 §27.16).
#
# Abstracts the cloud platforms behind one contract. The common layer hands off
# {business_profile, technical_requirements, selected_option, target_platform};
# this dispatcher validates the envelope, routes to the chosen platform boundary
# (S-42 aws / S-43 azure / S-44 gcp), derives the platform-aware IaC targets and
# build units from the selected option, and normalizes an INJECTED native API
# response (the boundaries' AWS WA Tool / Azure Advisor / GCP Recommender output
# is injected as a fixture, keeping the suite hermetic) into the common output
# {platform, route, recommendations, iac_targets, build_units, native_review_ref}.
#
# CLI:
#   --options <json>          S-34 architecture-options.json (required)
#   --select <option_id>      the chosen option (required; must exist)
#   --platform <aws|azure|gcp>  target platform (required)
#   --profile <json>          S-32 business-profile.json (ref recorded)
#   --requirements <json>     S-33 technical-requirements.json (ref recorded)
#   --native-response <json>  injected native API response to normalize (optional)
#   --out <json>              output (default standards/platform-handoff.json)
#   --now <iso>               generated_at (default current UTC)
#   --dry-run                 preview to stderr; write nothing (S2.14)
#
# stderr: handoff=<path> route=<boundary> platform=<p> selected=<id>
#         iac_tool=<t> recommendations=<n>
# Exit: 0 success / 2 usage or validation error.

set -uo pipefail

OPTS=""; SELECT=""; PLATFORM=""; PROFILE=""; REQ=""; NATIVE=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --options)         OPTS="${2-}";     shift 2 ;;
    --select)          SELECT="${2-}";   shift 2 ;;
    --platform)        PLATFORM="${2-}"; shift 2 ;;
    --profile)         PROFILE="${2-}";  shift 2 ;;
    --requirements)    REQ="${2-}";      shift 2 ;;
    --native-response) NATIVE="${2-}";   shift 2 ;;
    --out)             OUT="${2-}";      shift 2 ;;
    --now)             NOW="${2-}";      shift 2 ;;
    --dry-run)         DRY_RUN=1;        shift ;;
    -h|--help) echo "Usage: platform-boundary.sh --options <json> --select <id> --platform <aws|azure|gcp> [--native-response <json>] [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "platform-boundary: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OPTS" ]; then echo "platform-boundary: --options <json> is required" >&2; exit 2; fi
if [ ! -f "$OPTS" ]; then echo "platform-boundary: options not found: $OPTS" >&2; exit 2; fi
if [ -z "$SELECT" ]; then echo "platform-boundary: --select <option_id> is required" >&2; exit 2; fi
case "$PLATFORM" in
  aws|azure|gcp) ;;
  *) echo "platform-boundary: invalid --platform '$PLATFORM' (aws|azure|gcp)" >&2; exit 2 ;;
esac
if [ -z "$OUT" ]; then OUT="standards/platform-handoff.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

OPTS="$OPTS" SELECT="$SELECT" PLATFORM="$PLATFORM" PROFILE="$PROFILE" REQ="$REQ" \
NATIVE="$NATIVE" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  optf=ENV["OPTS"]; select=ENV["SELECT"]; platform=ENV["PLATFORM"]; profile=ENV["PROFILE"]
  req=ENV["REQ"]; native=ENV["NATIVE"]; out=ENV["OUT"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  doc = JSON.parse(File.read(optf))
  options = doc["options"] || []
  chosen = options.find { |o| o["option_id"] == select }
  if chosen.nil?
    STDERR.puts "platform-boundary: selected option not found: #{select}"
    exit 2
  end

  # Routing + platform-aware IaC tool.
  ROUTE = {"aws"=>"aws-boundary","azure"=>"azure-boundary","gcp"=>"gcp-boundary"}
  IAC   = {"aws"=>"terraform","azure"=>"bicep","gcp"=>"terraform"}
  route = ROUTE[platform]
  iac_tool = IAC[platform]

  # Normalize an injected native API response (enrichment from the boundary).
  recommendations = []
  native_review_ref = nil
  unless native.empty?
    nr = (File.exist?(native) ? JSON.parse(File.read(native)) : JSON.parse(native)) rescue nil
    if nr.is_a?(Hash)
      native_review_ref = nr["review_ref"]
      (nr["recommendations"] || []).each do |r|
        recommendations << {
          "id"     => r["id"],
          "title"  => r["title"],
          "pillar" => r["pillar"],
          "source" => "native-#{platform}"
        }
      end
    end
  end

  envelope = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "platform"       => platform,
    "route"          => route,
    "handoff"        => {
      "business_profile_ref"      => (profile.empty? ? nil : profile),
      "technical_requirements_ref"=> (req.empty? ? nil : req),
      "selected_option"           => select,
      "target_platform"           => platform
    },
    "selected_option" => {
      "option_id"          => chosen["option_id"],
      "summary"            => chosen["summary"],
      "build_requirements" => chosen["build_requirements"] || []
    },
    "iac_targets"      => [iac_tool],
    "build_units"      => chosen["build_requirements"] || [],
    "recommendations"  => recommendations,
    "native_review_ref"=> native_review_ref
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(envelope) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "handoff=#{out}"
  STDERR.puts "route=#{route}"
  STDERR.puts "platform=#{platform}"
  STDERR.puts "selected=#{select}"
  STDERR.puts "iac_tool=#{iac_tool}"
  STDERR.puts "recommendations=#{recommendations.length}"
'
exit $?
