#!/usr/bin/env bash
# commands/well-architected-review.sh — S-26 Well-Architected pillar review
# (v1.12 §27.10).
#
# Per §27.10 S-26: given a workload description and the active cloud-
# architecture sources, emits a review scaffold organised by the six
# Well-Architected pillars. Each pillar lists the grounding sources that
# cover it (from the S-23 catalog `pillars` field), with findings /
# trade_offs / risk_tier slots; a pillar with no grounding source is marked
# needs_grounding (mirrors the S-8 standards-comparator decline contract).
# Output standards/well-architected-reviews/<utc>.md + .json.
#
# This is an operator-facing application surface over the S-23 seed; it adds
# no fetch/diff logic and fabricates no source content — it maps pillars to
# the real grounding sources and leaves findings for the architect / a
# grounded S-8 review pass to fill.
#
# CLI:
#   --workload <text>   workload description under review (required)
#   --catalog <path>    cloud-architecture catalog
#                       (default standards/cloud-architecture-sources.yaml)
#   --out-dir <dir>     output dir (default standards/well-architected-reviews)
#   --now <iso>         generated_at + filename stamp (default current UTC)
#   --dry-run           preview to stderr; write no files (§2.14)
#
# stderr: review_json=<path> review_md=<path> pillars_reviewed=6
#         grounded=<k> needs_grounding=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

WORKLOAD=""
CATALOG=""
OUT_DIR=""
NOW=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workload) WORKLOAD="${2-}"; shift 2 ;;
    --catalog)  CATALOG="${2-}";  shift 2 ;;
    --out-dir)  OUT_DIR="${2-}";  shift 2 ;;
    --now)      NOW="${2-}";      shift 2 ;;
    --dry-run)  DRY_RUN=1;        shift ;;
    -h|--help)
      echo "Usage: well-architected-review.sh --workload <text> [--catalog <path>] [--out-dir <dir>] [--now <iso>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "well-architected-review: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$WORKLOAD" ]; then
  echo "well-architected-review: --workload <text> is required" >&2
  exit 2
fi
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
if [ ! -f "$CATALOG" ] && [ -f "$PLUGIN_ROOT/$CATALOG" ]; then CATALOG="$PLUGIN_ROOT/$CATALOG"; fi
if [ ! -f "$CATALOG" ]; then
  echo "well-architected-review: catalog not found: $CATALOG" >&2
  exit 2
fi
if [ -z "$OUT_DIR" ]; then OUT_DIR="standards/well-architected-reviews"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
STAMP=$(printf '%s' "$NOW" | tr -d ':')

WORKLOAD="$WORKLOAD" CATALOG="$CATALOG" OUT_DIR="$OUT_DIR" STAMP="$STAMP" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  workload = ENV["WORKLOAD"]
  catalog  = ENV["CATALOG"]
  out_dir  = ENV["OUT_DIR"]
  stamp    = ENV["STAMP"]
  now      = ENV["NOW"]
  dry_run  = ENV["DRY_RUN"] == "1"

  PILLARS = %w[operational-excellence security reliability performance-efficiency cost-optimization sustainability]

  doc = begin
    YAML.unsafe_load_file(catalog)
  rescue
    nil
  end
  entries = doc.is_a?(Array) ? doc : []

  # pillar -> [source_id, ...]
  by_pillar = {}
  PILLARS.each { |p| by_pillar[p] = [] }
  entries.each do |e|
    next unless e.is_a?(Hash) && e["id"]
    ps = e["pillars"]
    next unless ps.is_a?(Array)
    ps.each { |p| (by_pillar[p] ||= []) << e["id"] if by_pillar.key?(p) }
  end

  grounded = 0
  needs = 0
  pillar_records = PILLARS.map do |p|
    sources = (by_pillar[p] || []).sort.uniq
    status = sources.empty? ? "needs_grounding" : "grounded"
    grounded += 1 if status == "grounded"
    needs += 1 if status == "needs_grounding"
    {
      "pillar"            => p,
      "grounding_sources" => sources,
      "grounded"          => !sources.empty?,
      "status"            => status,
      "findings"          => "",
      "trade_offs"        => "",
      "risk_tier"         => "to-assess"
    }
  end

  review = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "workload"       => workload,
    "pillars"        => pillar_records
  }
  json = JSON.pretty_generate(review)

  md = +""
  md << "# Well-Architected Review - #{now}\n\n"
  md << "Workload: #{workload}\n\n"
  pillar_records.each do |pr|
    md << "## #{pr["pillar"]} (#{pr["status"]})\n"
    if pr["grounding_sources"].empty?
      md << "- No grounding source in the active catalog for this pillar (needs_grounding).\n"
    else
      md << "- Grounding sources: #{pr["grounding_sources"].join(", ")}\n"
    end
    md << "- Findings: (to assess)\n- Trade-offs: (to assess)\n- Risk tier: to-assess\n\n"
  end

  json_path = "#{out_dir}/#{stamp}.json"
  md_path   = "#{out_dir}/#{stamp}.md"

  unless dry_run
    require "fileutils"
    FileUtils.mkdir_p(out_dir)
    File.write(json_path, json + "\n")
    File.write(md_path, md)
  end

  STDERR.puts "dry_run=true" if dry_run
  STDERR.puts "review_json=#{json_path}"
  STDERR.puts "review_md=#{md_path}"
  STDERR.puts "pillars_reviewed=#{pillar_records.length}"
  STDERR.puts "grounded=#{grounded}"
  STDERR.puts "needs_grounding=#{needs}"
'
exit 0
