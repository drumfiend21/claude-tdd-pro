#!/usr/bin/env bash
# commands/curriculum-digest.sh - S-24 continuous cloud-architecture education
# digest (v1.12 §27).
#
# Per §27 S-24: "rolls up the cross-source delta since last review into an
# operator-readable brief organised by the six Well-Architected pillars and
# six curriculum phases; surfaces new technologies as an explicit
# new_technology delta class. Output standards/curriculum-digest/<utc>.md
# + .json."
#
# The digest is a rollup/serializer over a delta stream (the polled
# content_hash changes from S-21 + S-5 diffs, tagged with the source's
# §27 curriculum_phase and Well-Architected pillar). Deltas are injected
# via --deltas for hermetic testing and by the S-25 study loop / S-10
# monitor in production. The .json is the topic-divided machine surface the
# S-25 curriculum study loop consumes (one topic per delta); the .md is the
# human brief.
#
# CLI:
#   --deltas <jsonl>   delta records, one JSON object per line:
#                      {source_id, section_id, pillar, curriculum_phase,
#                       delta_class (best_practice_updated|new_technology),
#                       summary, fetched_at}
#   --out-dir <dir>    output dir (default standards/curriculum-digest)
#   --now <iso>        generated_at + filename stamp (default current UTC)
#   --dry-run          preview to stderr; write no files (§2.14)
#
# stderr: digest_json=<path> digest_md=<path> topic_count=<N>
#         best_practice_updated=<a> new_technology=<b> pillars_present=<list>
#         (dry-run: dry_run=true and no files written)
# Exit: 0 success / 2 usage error.

set -uo pipefail

DELTAS=""
OUT_DIR=""
NOW=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --deltas)  DELTAS="${2-}";  shift 2 ;;
    --out-dir) OUT_DIR="${2-}"; shift 2 ;;
    --now)     NOW="${2-}";     shift 2 ;;
    --dry-run) DRY_RUN=1;       shift ;;
    -h|--help)
      echo "Usage: curriculum-digest.sh [--deltas <jsonl>] [--out-dir <dir>] [--now <iso>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "curriculum-digest: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OUT_DIR" ]; then OUT_DIR="standards/curriculum-digest"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi
# Filename stamp: colons are awkward in filenames; strip to keep it portable.
STAMP=$(printf '%s' "$NOW" | tr -d ':')

# Build the digest (group by pillar + phase, split new_technology) via ruby.
# Deterministic ordering for reproducibility: deltas sorted by
# [pillar, curriculum_phase, source_id, section_id]; canonical pillar order.
DELTAS="$DELTAS" NOW="$NOW" OUT_DIR="$OUT_DIR" STAMP="$STAMP" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  deltas_path = ENV["DELTAS"]
  now         = ENV["NOW"]
  out_dir     = ENV["OUT_DIR"]
  stamp       = ENV["STAMP"]
  dry_run     = ENV["DRY_RUN"] == "1"

  PILLARS = %w[operational-excellence security reliability performance-efficiency cost-optimization sustainability]
  PHASES  = %w[1 2 3 4 5 6]

  deltas = []
  if deltas_path && !deltas_path.empty? && File.exist?(deltas_path)
    File.foreach(deltas_path) do |line|
      line = line.strip
      next if line.empty?
      begin
        d = JSON.parse(line)
      rescue
        next
      end
      next unless d.is_a?(Hash) && d["source_id"]
      deltas << {
        "source_id"        => d["source_id"].to_s,
        "section_id"       => (d["section_id"] || "").to_s,
        "pillar"           => (d["pillar"] || "uncategorized").to_s,
        "curriculum_phase" => (d["curriculum_phase"] || "").to_s,
        "delta_class"      => (d["delta_class"] || "best_practice_updated").to_s,
        "summary"          => (d["summary"] || "").to_s,
        "fetched_at"       => (d["fetched_at"] || "").to_s
      }
    end
  end

  # Deterministic sort.
  deltas.sort_by! { |d| [d["pillar"], d["curriculum_phase"], d["source_id"], d["section_id"]] }

  by_pillar = {}
  PILLARS.each { |p| by_pillar[p] = [] }
  by_phase = {}
  PHASES.each { |p| by_phase[p] = [] }
  best = []
  newtech = []

  deltas.each do |d|
    (by_pillar[d["pillar"]] ||= []) << d
    (by_phase[d["curriculum_phase"]] ||= []) << d
    if d["delta_class"] == "new_technology"
      newtech << d
    else
      best << d
    end
  end

  # Topic ids: one per delta (the S-25 study-loop unit).
  topics = deltas.each_with_index.map do |d, i|
    {
      "topic_id"         => "topic-#{stamp}-%03d" % i,
      "source_id"        => d["source_id"],
      "section_id"       => d["section_id"],
      "pillar"           => d["pillar"],
      "curriculum_phase" => d["curriculum_phase"],
      "delta_class"      => d["delta_class"],
      "summary"          => d["summary"],
      "fetched_at"       => d["fetched_at"]
    }
  end

  doc = {
    "schema_version"        => "1.0",
    "generated_at"          => now,
    "topic_count"           => deltas.length,
    "pillars"               => by_pillar,
    "phases"                => by_phase,
    "best_practices_updated"=> best,
    "new_technology"        => newtech,
    "topics"                => topics
  }

  json = JSON.pretty_generate(doc)

  # Human brief.
  md = +""
  md << "# Cloud-Architecture Education Digest - #{now}\n\n"
  md << "Topics: #{deltas.length}  (best-practice updates: #{best.length}, new technologies: #{newtech.length})\n\n"
  if deltas.empty?
    md << "_No changes since last review._\n"
  else
    md << "## By Well-Architected Pillar\n\n"
    PILLARS.each do |p|
      items = by_pillar[p] || []
      next if items.empty?
      md << "### #{p}\n"
      items.each { |d| md << "- [#{d["source_id"]} \u00A7#{d["section_id"]}] #{d["summary"]} (fetched_at: #{d["fetched_at"]}, phase #{d["curriculum_phase"]}, #{d["delta_class"]})\n" }
      md << "\n"
    end
    md << "## By Curriculum Phase\n\n"
    PHASES.each do |p|
      items = by_phase[p] || []
      next if items.empty?
      md << "### Phase #{p}\n"
      items.each { |d| md << "- [#{d["source_id"]} \u00A7#{d["section_id"]}] #{d["summary"]} (fetched_at: #{d["fetched_at"]})\n" }
      md << "\n"
    end
    unless newtech.empty?
      md << "## New Technologies\n\n"
      newtech.each { |d| md << "- [#{d["source_id"]} \u00A7#{d["section_id"]}] #{d["summary"]} (fetched_at: #{d["fetched_at"]})\n" }
      md << "\n"
    end
  end

  pillars_present = PILLARS.select { |p| !(by_pillar[p] || []).empty? }.join(",")

  json_path = "#{out_dir}/#{stamp}.json"
  md_path   = "#{out_dir}/#{stamp}.md"

  if dry_run
    STDERR.puts "dry_run=true"
    STDERR.puts "digest_json=#{json_path}"
    STDERR.puts "digest_md=#{md_path}"
    STDERR.puts "topic_count=#{deltas.length}"
    STDERR.puts "best_practice_updated=#{best.length}"
    STDERR.puts "new_technology=#{newtech.length}"
    STDERR.puts "pillars_present=#{pillars_present}"
  else
    require "fileutils"
    FileUtils.mkdir_p(out_dir)
    File.write(json_path, json + "\n")
    File.write(md_path, md)
    STDERR.puts "digest_json=#{json_path}"
    STDERR.puts "digest_md=#{md_path}"
    STDERR.puts "topic_count=#{deltas.length}"
    STDERR.puts "best_practice_updated=#{best.length}"
    STDERR.puts "new_technology=#{newtech.length}"
    STDERR.puts "pillars_present=#{pillars_present}"
  end
'
exit 0
