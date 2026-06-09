#!/usr/bin/env bash
# commands/cloud-build.sh - S-29 cloud-architecture build units (v1.12 §27.12).
#
# Turns a cloud design decision (an S-28 ADR) into a TEST-FIRST IaC build unit,
# so the architecture the cloud-architect layer designs is developed with the
# same excellence as every other type of code the plugin builds: spec-first,
# standards-grounded, ADR-traced, red-until-green.
#
# Actions:
#   scaffold (default)  write the conformance spec (the test) + an IaC stub +
#                       a grounding manifest + unit metadata, all at once. The
#                       fresh unit is RED (conformance not yet satisfied).
#   check               run the conformance spec against the IaC file; exit 0
#                       when GREEN (all requirements present), 1 when RED.
#
# CLI (scaffold):
#   --from-adr <json>   an S-28 ADR json (supplies decision_id, pillar, title)
#   --decision-id <id>  override / supply the decision id
#   --pillar <p>        override / supply the Well-Architected pillar
#   --title <t>         override / supply the decision title
#   --tool <terraform|bicep|cloudformation>   IaC tool (default terraform)
#   --requirements <csv>  conformance tokens the IaC must contain
#                         (default: per-pillar defaults)
#   --catalog <path>    cloud-architecture catalog (for grounding)
#   --build-dir <dir>   build root (default standards/cloud-build)
#   --now <iso>         created_at (default current UTC)
#   --dry-run           preview to stderr; write nothing (§2.14)
# CLI (check):
#   --build-dir <dir> --unit <decision_id>   (or --from-adr to supply the id)
#
# Exit: 0 ok/green / 1 red (check) / 2 usage error.

set -uo pipefail

ACTION="scaffold"
case "${1-}" in
  scaffold|check) ACTION="$1"; shift ;;
esac

FROM_ADR=""; DECISION_ID=""; PILLAR=""; TITLE=""; TOOL="terraform"
REQUIREMENTS=""; CATALOG=""; BUILD_DIR=""; NOW=""; DRY_RUN=0; UNIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from-adr)     FROM_ADR="${2-}";     shift 2 ;;
    --decision-id)  DECISION_ID="${2-}";  shift 2 ;;
    --pillar)       PILLAR="${2-}";       shift 2 ;;
    --title)        TITLE="${2-}";        shift 2 ;;
    --tool)         TOOL="${2-}";         shift 2 ;;
    --requirements) REQUIREMENTS="${2-}"; shift 2 ;;
    --catalog)      CATALOG="${2-}";      shift 2 ;;
    --build-dir)    BUILD_DIR="${2-}";    shift 2 ;;
    --now)          NOW="${2-}";          shift 2 ;;
    --unit)         UNIT="${2-}";         shift 2 ;;
    --dry-run)      DRY_RUN=1;            shift ;;
    -h|--help)
      echo "Usage: cloud-build.sh [scaffold|check] --from-adr <json> | --decision-id <id> --pillar <p> [--tool ...] [--requirements <csv>] [--build-dir <dir>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "cloud-build: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ ! -f "$CATALOG" ] && [ -f "$PLUGIN_ROOT/$CATALOG" ]; then CATALOG="$PLUGIN_ROOT/$CATALOG"; fi
if [ -z "$BUILD_DIR" ]; then BUILD_DIR="standards/cloud-build"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
case "$TOOL" in
  terraform|bicep|cloudformation) ;;
  *) echo "cloud-build: invalid --tool $TOOL (terraform|bicep|cloudformation)" >&2; exit 2 ;;
esac

ACTION="$ACTION" FROM_ADR="$FROM_ADR" DECISION_ID="$DECISION_ID" PILLAR="$PILLAR" TITLE="$TITLE" \
TOOL="$TOOL" REQUIREMENTS="$REQUIREMENTS" CATALOG="$CATALOG" BUILD_DIR="$BUILD_DIR" NOW="$NOW" \
DRY_RUN="$DRY_RUN" UNIT="$UNIT" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  action=ENV["ACTION"]; from_adr=ENV["FROM_ADR"]; decision_id=ENV["DECISION_ID"]
  pillar=ENV["PILLAR"]; title=ENV["TITLE"]; tool=ENV["TOOL"]; reqs=ENV["REQUIREMENTS"]
  catalog=ENV["CATALOG"]; build_dir=ENV["BUILD_DIR"]; now=ENV["NOW"]
  dry_run=ENV["DRY_RUN"]=="1"; unit_arg=ENV["UNIT"]

  PILLAR_DEFAULTS = {
    "operational-excellence" => %w[monitoring versioning],
    "security"               => %w[encryption least_privilege logging],
    "reliability"            => %w[multi_az backup health_check],
    "performance-efficiency" => %w[autoscaling caching],
    "cost-optimization"      => %w[rightsizing tagging],
    "sustainability"         => %w[rightsizing managed_services]
  }
  EXT = { "terraform" => "tf", "bicep" => "bicep", "cloudformation" => "json" }

  # Pull fields from the ADR when provided (explicit flags win).
  if !from_adr.empty? && File.exist?(from_adr)
    adr = begin; JSON.parse(File.read(from_adr)); rescue; {}; end
    decision_id = adr["decision_id"].to_s if decision_id.empty? && adr["decision_id"]
    pillar      = adr["pillar"].to_s      if pillar.empty?      && adr["pillar"]
    title       = adr["title"].to_s       if title.empty?       && adr["title"]
  end

  if action == "check"
    id = !unit_arg.empty? ? unit_arg : decision_id
    if id.empty?
      STDERR.puts "cloud-build: check requires --unit <decision_id> or --from-adr"
      exit 2
    end
    unit_dir = "#{build_dir}/#{id}"
    conf_path = "#{unit_dir}/conformance.json"
    unit_path = "#{unit_dir}/unit.json"
    unless File.exist?(conf_path) && File.exist?(unit_path)
      STDERR.puts "cloud-build: no build unit at #{unit_dir}"
      exit 2
    end
    conf = JSON.parse(File.read(conf_path))
    u    = JSON.parse(File.read(unit_path))
    iac_path = "#{unit_dir}/#{u["iac_file"]}"
    iac = File.exist?(iac_path) ? File.read(iac_path) : ""
    missing = (conf["requirements"] || []).reject { |r| iac.include?(r) }
    if missing.empty?
      STDERR.puts "conformance=green"
      STDERR.puts "decision_id=#{id}"
      exit 0
    else
      STDERR.puts "conformance=red"
      STDERR.puts "missing=#{missing.join(",")}"
      STDERR.puts "decision_id=#{id}"
      exit 1
    end
  end

  # action == scaffold
  if decision_id.empty? || pillar.empty?
    STDERR.puts "cloud-build: scaffold requires a decision id and pillar (via --from-adr or --decision-id/--pillar)"
    exit 2
  end

  requirements = reqs.split(",").map(&:strip).reject(&:empty?)
  requirements = (PILLAR_DEFAULTS[pillar] || []) if requirements.empty?

  # Grounding sources for the pillar (from the S-23 catalog pillars field).
  sources = []
  doc = begin; YAML.unsafe_load_file(catalog); rescue; nil; end
  if doc.is_a?(Array)
    doc.each do |e|
      next unless e.is_a?(Hash) && e["id"] && e["pillars"].is_a?(Array)
      sources << e["id"] if e["pillars"].include?(pillar)
    end
  end
  sources = sources.sort.uniq
  grounding = sources.empty? ? "needs_grounding" : "grounded"

  ext = EXT[tool]
  iac_file = "main.#{ext}"
  unit_dir = "#{build_dir}/#{decision_id}"

  # IaC stub deliberately omits the requirement tokens, so the fresh unit is RED.
  iac_stub  = "# Cloud build unit for decision #{decision_id}\n"
  iac_stub << "# pillar: #{pillar}  tool: #{tool}\n"
  iac_stub << "# Status: scaffolded. Implement resources until conformance.json is satisfied.\n"

  conformance = {
    "decision_id"       => decision_id,
    "pillar"            => pillar,
    "requirements"      => requirements,
    "grounding"         => grounding,
    "grounding_sources" => sources
  }
  unit = {
    "unit_id"     => "unit-#{decision_id}",
    "decision_id" => decision_id,
    "title"       => title,
    "pillar"      => pillar,
    "tool"        => tool,
    "iac_file"    => iac_file,
    "status"      => "red",
    "created_at"  => now
  }
  grounding_doc = { "pillar" => pillar, "grounding" => grounding, "sources" => sources }

  unless dry_run
    require "fileutils"
    FileUtils.mkdir_p(unit_dir)
    File.write("#{unit_dir}/conformance.json", JSON.pretty_generate(conformance) + "\n")
    File.write("#{unit_dir}/#{iac_file}", iac_stub)
    File.write("#{unit_dir}/grounding.json", JSON.pretty_generate(grounding_doc) + "\n")
    File.write("#{unit_dir}/unit.json", JSON.pretty_generate(unit) + "\n")
  end

  STDERR.puts "dry_run=true" if dry_run
  STDERR.puts "unit_dir=#{unit_dir}"
  STDERR.puts "iac_file=#{iac_file}"
  STDERR.puts "decision_id=#{decision_id}"
  STDERR.puts "pillar=#{pillar}"
  STDERR.puts "tool=#{tool}"
  STDERR.puts "status=red"
  STDERR.puts "grounding=#{grounding}"
  STDERR.puts "requirements=#{requirements.join(",")}"
'
exit $?
