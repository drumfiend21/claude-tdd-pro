#!/usr/bin/env bash
# commands/curriculum-progress.sh — S-27 curriculum progress and gap tracker
# (v1.12 §27.10).
#
# Per §27.10 S-27: reads the S-25 ledger + S-23 catalog and reports per-pillar
# and per-curriculum-phase coverage (studied vs available) plus the
# not-yet-studied gaps. Output standards/curriculum-progress/<utc>.md + .json.
#
# "studied" = a topic recorded as learned in the S-25 ledger. "available" is
# derived from the S-23 catalog's per-source pillars + curriculum_phase tags.
# A pillar/phase that the catalog covers but the ledger has not yet studied is
# a gap.
#
# CLI:
#   --ledger <jsonl>   S-25 learning ledger
#                      (default standards/curriculum-ledger.jsonl)
#   --catalog <path>   S-23 catalog
#                      (default standards/cloud-architecture-sources.yaml)
#   --out-dir <dir>    output dir (default standards/curriculum-progress)
#   --now <iso>        generated_at + filename stamp (default current UTC)
#   --dry-run          preview to stderr; write no files (§2.14)
#
# stderr: progress_json=<path> progress_md=<path>
#         pillars_studied=<a>/<b> phases_studied=<c>/<d> gaps=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

LEDGER=""
CATALOG=""
OUT_DIR=""
NOW=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ledger)  LEDGER="${2-}";  shift 2 ;;
    --catalog) CATALOG="${2-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2-}"; shift 2 ;;
    --now)     NOW="${2-}";     shift 2 ;;
    --dry-run) DRY_RUN=1;       shift ;;
    -h|--help)
      echo "Usage: curriculum-progress.sh [--ledger <jsonl>] [--catalog <path>] [--out-dir <dir>] [--now <iso>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "curriculum-progress: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
if [ -z "$LEDGER" ]; then LEDGER="standards/curriculum-ledger.jsonl"; fi
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ ! -f "$CATALOG" ] && [ -f "$PLUGIN_ROOT/$CATALOG" ]; then CATALOG="$PLUGIN_ROOT/$CATALOG"; fi
if [ ! -f "$CATALOG" ]; then
  echo "curriculum-progress: catalog not found: $CATALOG" >&2
  exit 2
fi
if [ -z "$OUT_DIR" ]; then OUT_DIR="standards/curriculum-progress"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
STAMP=$(printf '%s' "$NOW" | tr -d ':')

LEDGER="$LEDGER" CATALOG="$CATALOG" OUT_DIR="$OUT_DIR" STAMP="$STAMP" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  ledger  = ENV["LEDGER"]
  catalog = ENV["CATALOG"]
  out_dir = ENV["OUT_DIR"]
  stamp   = ENV["STAMP"]
  now     = ENV["NOW"]
  dry_run = ENV["DRY_RUN"] == "1"

  PILLARS = %w[operational-excellence security reliability performance-efficiency cost-optimization sustainability]
  PHASES  = %w[1 2 3 4 5 6]

  doc = begin; YAML.unsafe_load_file(catalog); rescue; nil; end
  entries = doc.is_a?(Array) ? doc : []

  # available pillars / phases from the catalog
  avail_pillars = {}
  avail_phases  = {}
  entries.each do |e|
    next unless e.is_a?(Hash)
    (e["pillars"] || []).each { |p| avail_pillars[p] = true } if e["pillars"].is_a?(Array)
    ph = e["curriculum_phase"]
    avail_phases[ph.to_s] = true unless ph.nil? || ph.to_s.empty?
  end

  # studied pillars / phases from the ledger (state learned)
  studied_pillars = {}
  studied_phases  = {}
  if File.exist?(ledger)
    File.foreach(ledger) do |line|
      line = line.strip
      next if line.empty?
      r = begin; JSON.parse(line); rescue; nil; end
      next unless r.is_a?(Hash) && r["state"] == "learned"
      studied_pillars[r["pillar"]] = true if r["pillar"] && !r["pillar"].to_s.empty?
      studied_phases[r["curriculum_phase"].to_s] = true if r["curriculum_phase"] && !r["curriculum_phase"].to_s.empty?
    end
  end

  pillar_rows = PILLARS.map do |p|
    avail = !!avail_pillars[p]
    studied = !!studied_pillars[p]
    { "pillar" => p, "available" => avail, "studied" => studied, "gap" => (avail && !studied) }
  end
  phase_rows = PHASES.map do |p|
    avail = !!avail_phases[p]
    studied = !!studied_phases[p]
    { "phase" => p, "available" => avail, "studied" => studied, "gap" => (avail && !studied) }
  end

  pillar_gaps = pillar_rows.select { |r| r["gap"] }.map { |r| r["pillar"] }
  phase_gaps  = phase_rows.select { |r| r["gap"] }.map { |r| r["phase"] }
  pillars_studied = pillar_rows.count { |r| r["studied"] }
  pillars_avail   = pillar_rows.count { |r| r["available"] }
  phases_studied  = phase_rows.count { |r| r["studied"] }
  phases_avail    = phase_rows.count { |r| r["available"] }
  gaps = pillar_gaps.length + phase_gaps.length

  report = {
    "schema_version"  => "1.0",
    "generated_at"    => now,
    "pillar_coverage" => pillar_rows,
    "phase_coverage"  => phase_rows,
    "pillar_gaps"     => pillar_gaps,
    "phase_gaps"      => phase_gaps,
    "mastery"         => { "pillars_studied" => pillars_studied, "pillars_available" => pillars_avail, "phases_studied" => phases_studied, "phases_available" => phases_avail }
  }
  json = JSON.pretty_generate(report)

  md = +""
  md << "# Cloud-Architecture Curriculum Progress - #{now}\n\n"
  md << "Pillars studied: #{pillars_studied}/#{pillars_avail}  |  Phases studied: #{phases_studied}/#{phases_avail}\n\n"
  md << "## Pillar coverage\n"
  pillar_rows.each { |r| md << "- #{r["pillar"]}: #{r["studied"] ? "studied" : (r["available"] ? "GAP" : "n/a")}\n" }
  md << "\n## Curriculum phase coverage\n"
  phase_rows.each { |r| md << "- Phase #{r["phase"]}: #{r["studied"] ? "studied" : (r["available"] ? "GAP" : "n/a")}\n" }
  md << "\n## Gaps (available but not yet studied)\n"
  md << "- Pillars: #{pillar_gaps.empty? ? "none" : pillar_gaps.join(", ")}\n"
  md << "- Phases: #{phase_gaps.empty? ? "none" : phase_gaps.join(", ")}\n"

  json_path = "#{out_dir}/#{stamp}.json"
  md_path   = "#{out_dir}/#{stamp}.md"
  unless dry_run
    require "fileutils"
    FileUtils.mkdir_p(out_dir)
    File.write(json_path, json + "\n")
    File.write(md_path, md)
  end

  STDERR.puts "dry_run=true" if dry_run
  STDERR.puts "progress_json=#{json_path}"
  STDERR.puts "progress_md=#{md_path}"
  STDERR.puts "pillars_studied=#{pillars_studied}/#{pillars_avail}"
  STDERR.puts "phases_studied=#{phases_studied}/#{phases_avail}"
  STDERR.puts "gaps=#{gaps}"
'
exit 0
