#!/usr/bin/env bash
# commands/azure-boundary.sh - S-43 Azure platform boundary (v1.14 §27.16;
# safety + normalization contracts §27.19).
#
# The Azure expert boundary. Consumes the S-41 platform-handoff (platform must
# be azure), normalizes an INJECTED Azure Advisor response into the same
# plugin-standard boundary response as every other boundary (§27.19 Contract B),
# and is SAFE-BY-DEFAULT: never issues a mutating external call for an invalid
# platform or unknown option, and only with --apply after validation passes
# (§27.19 Contract A). Native response injected for hermetic testing.
#
# CLI: identical surface to aws-boundary.sh.
#   --handoff <json>          S-41 platform-handoff.json (platform must be azure)
#   --native-response <json>  injected Azure Advisor response to normalize
#   --apply                   authorize a mutating external call (default: off)
#   --catalog / --eng-catalog grounding catalogs (default resolved)
#   --out <json>              default standards/azure-boundary-response.json
#   --now <iso> / --dry-run
#
# stderr: boundary=azure validated=<true|false> normalized_recommendations=<n>
#         external_call=<skipped-not-applied|apply-authorized|blocked-validation-failed>
#         needs_grounding=<n> | validation_failed=<reason>
# Exit: 0 success / 2 validation or usage error.

set -uo pipefail

HANDOFF=""; NATIVE=""; APPLY=0; CATALOG=""; ENG=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --handoff)         HANDOFF="${2-}"; shift 2 ;;
    --native-response) NATIVE="${2-}";  shift 2 ;;
    --apply)           APPLY=1;         shift ;;
    --catalog)         CATALOG="${2-}"; shift 2 ;;
    --eng-catalog)     ENG="${2-}";     shift 2 ;;
    --out)             OUT="${2-}";     shift 2 ;;
    --now)             NOW="${2-}";     shift 2 ;;
    --dry-run)         DRY_RUN=1;       shift ;;
    -h|--help) echo "Usage: azure-boundary.sh --handoff <json> [--native-response <json>] [--apply] [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "azure-boundary: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$HANDOFF" ]; then echo "azure-boundary: --handoff <json> is required" >&2; exit 2; fi
if [ ! -f "$HANDOFF" ]; then echo "azure-boundary: handoff not found: $HANDOFF" >&2; exit 2; fi
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ -z "$ENG" ]; then ENG="standards/cloud-engineering-sources.yaml"; fi
CATALOG=$(resolve "$CATALOG"); ENG=$(resolve "$ENG")
if [ -z "$OUT" ]; then OUT="standards/azure-boundary-response.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

HANDOFF="$HANDOFF" NATIVE="$NATIVE" APPLY="$APPLY" CATALOG="$CATALOG" ENG="$ENG" \
OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  handoff=ENV["HANDOFF"]; native=ENV["NATIVE"]; apply=ENV["APPLY"]=="1"
  catalog=ENV["CATALOG"]; eng=ENV["ENG"]; out=ENV["OUT"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  PLATFORM = "azure"
  SOURCE_API = "azure-advisor"

  h = begin; JSON.parse(File.read(handoff)); rescue; nil; end

  # ---- §27.19 Contract A: validation BEFORE any external interaction ----
  reason = nil
  reason = "handoff-not-json" if h.nil?
  reason ||= "wrong-platform" unless h["platform"] == PLATFORM
  sel = h.is_a?(Hash) ? (h["selected_option"] || {}) : {}
  reason ||= "unknown-option" if sel.nil? || sel["option_id"].to_s.empty?

  if reason
    STDERR.puts "external_call=blocked-validation-failed" if apply
    STDERR.puts "boundary=azure"
    STDERR.puts "validated=false"
    STDERR.puts "validation_failed=#{reason}"
    exit 2
  end

  # ---- Normalize the injected Azure Advisor response (§27.19 Contract B) ----
  grounded = {}
  [catalog, eng].each do |c|
    next unless File.exist?(c)
    d = begin; YAML.unsafe_load_file(c); rescue; nil; end
    next unless d.is_a?(Array)
    d.each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end
  MAP = [
    [%w[encrypt encryption], "encryption_at_rest", "nist-800-53"],
    [%w[availability multi-az multi_az zone], "multi_az", "aws-reliability-pillar"],
    [%w[backup recovery], "backup", "aws-rpo-rto-targets"],
    [%w[logging audit monitor], "audit_logging", "nist-800-53"],
    [%w[scaling autoscal performance], "autoscaling", "aws-well-architected"],
    [%w[cost rightsiz spend], "rightsizing", "finops-framework"]
  ]
  # Azure Advisor category -> Well-Architected pillar.
  CAT = {"Security"=>"security","HighAvailability"=>"reliability","Reliability"=>"reliability",
         "Cost"=>"cost-optimization","Performance"=>"performance-efficiency",
         "OperationalExcellence"=>"operational-excellence"}
  map_concern = lambda do |title, pillar|
    t = "#{title} #{pillar}".downcase
    MAP.each { |kws, concern, src| return [concern, src] if kws.any? { |k| t.include?(k) } }
    [nil, nil]
  end

  recs = []
  native_review_ref = nil
  needs = 0
  unless native.empty?
    nr = (File.exist?(native) ? JSON.parse(File.read(native)) : JSON.parse(native)) rescue nil
    if nr.is_a?(Hash)
      native_review_ref = nr["review_ref"] || nr["resourceId"]
      items = nr["recommendations"] || nr["value"] || []
      items.each do |r|
        sd = r["shortDescription"] || {}
        title = r["title"] || sd["solution"] || sd["problem"]
        category = r["category"]
        pillar = r["pillar"] || CAT[category] || category
        concern, src = map_concern.call(title, pillar)
        grounding = (concern && grounded[src]) ? "grounded" : "needs_grounding"
        needs += 1 if grounding == "needs_grounding"
        recs << {
          "id"            => (r["id"] || r["recommendationId"]),
          "title"         => title,
          "pillar"        => pillar,
          "severity"      => (r["impact"] || r["severity"] || "unset"),
          "source"        => "native-#{PLATFORM}",
          "mapped_concern"=> concern,
          "grounding"     => grounding
        }
      end
    end
  end

  external_call = apply ? "apply-authorized" : "skipped-not-applied"

  response = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "platform"       => PLATFORM,
    "source_api"     => SOURCE_API,
    "validated"      => true,
    "applied"        => apply,
    "iac_targets"    => h["iac_targets"] || [],
    "build_units"    => h["build_units"] || [],
    "normalized"     => {
      "recommendations"   => recs,
      "native_review_ref" => native_review_ref
    }
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(response) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "boundary=azure"
  STDERR.puts "validated=true"
  STDERR.puts "response=#{out}"
  STDERR.puts "normalized_recommendations=#{recs.length}"
  STDERR.puts "external_call=#{external_call}"
  STDERR.puts "needs_grounding=#{needs}"
'
exit $?
