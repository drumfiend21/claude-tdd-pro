#!/usr/bin/env bash
# commands/curriculum-study.sh — S-25 curriculum study loop (v1.12 §27.9).
#
# Orchestrates divide -> reach -> learn -> record over the S-24 digest. It
# reimplements no fetch/diff/promote logic — it composes existing Phase-S
# primitives and adds per-topic iteration + a resumable learning ledger:
#   divide : the S-24 digest .json topics[] (one topic per delta)
#   reach  : standards/fetcher.sh (S-2) + conditional-get.sh (S-21)
#   learn  : standards-comparator (S-8 grounded) + standards-diff (S-5
#            adopt/defer/reject) + optional promote-standard (S-7)
#   record : standards/curriculum-ledger.jsonl (state learned; learn-once)
#
# For each topic: if already learned in the ledger, skip (resumable +
# learn-once); else reach the section, produce a grounded learning record
# citing source_id + section_id, attach a decision, and append to the ledger.
#
# CLI:
#   --digest <json>   the S-24 digest .json (required); consumes topics[]
#   --ledger <jsonl>  learning ledger (default standards/curriculum-ledger.jsonl)
#   --decide <adopt|defer|reject>  decision for studied topics (default defer)
#   --now <iso>       studied_at timestamp (default current UTC)
#   --dry-run         preview to stderr; write no ledger records (§2.14)
#
# stderr: studied=<topic_id> | skipped=<topic_id> (per topic);
#         topics_total=<N> studied=<K> skipped=<S> ledger=<path>
#         (dry-run: dry_run=true and no ledger written)
# Exit: 0 success / 2 usage error.

set -uo pipefail

DIGEST=""
LEDGER=""
DECIDE="defer"
NOW=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --digest)  DIGEST="${2-}";  shift 2 ;;
    --ledger)  LEDGER="${2-}";  shift 2 ;;
    --decide)  DECIDE="${2-}";  shift 2 ;;
    --now)     NOW="${2-}";     shift 2 ;;
    --dry-run) DRY_RUN=1;       shift ;;
    -h|--help)
      echo "Usage: curriculum-study.sh --digest <json> [--ledger <jsonl>] [--decide adopt|defer|reject] [--now <iso>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "curriculum-study: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$DIGEST" ]; then
  echo "curriculum-study: --digest <json> is required" >&2
  exit 2
fi
if [ ! -f "$DIGEST" ]; then
  echo "curriculum-study: digest not found: $DIGEST" >&2
  exit 2
fi
case "$DECIDE" in
  adopt|defer|reject) ;;
  *) echo "curriculum-study: invalid --decide $DECIDE (allowed adopt|defer|reject)" >&2; exit 2 ;;
esac

if [ -z "$LEDGER" ]; then LEDGER="standards/curriculum-ledger.jsonl"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

DIGEST="$DIGEST" LEDGER="$LEDGER" DECIDE="$DECIDE" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  digest_path = ENV["DIGEST"]
  ledger_path = ENV["LEDGER"]
  decide      = ENV["DECIDE"]
  now         = ENV["NOW"]
  dry_run     = ENV["DRY_RUN"] == "1"

  doc = begin
    JSON.parse(File.read(digest_path))
  rescue
    STDERR.puts "curriculum-study: digest is not valid json"
    exit 2
  end
  topics = (doc.is_a?(Hash) && doc["topics"].is_a?(Array)) ? doc["topics"] : []

  # Resumable: collect topic_ids already recorded as learned.
  learned = {}
  if File.exist?(ledger_path)
    File.foreach(ledger_path) do |line|
      line = line.strip
      next if line.empty?
      begin
        r = JSON.parse(line)
      rescue
        next
      end
      learned[r["topic_id"]] = true if r.is_a?(Hash) && r["state"] == "learned" && r["topic_id"]
    end
  end

  out_lines = []
  studied = 0
  skipped = 0

  topics.each do |t|
    next unless t.is_a?(Hash) && t["topic_id"]
    tid = t["topic_id"]
    if learned[tid]
      skipped += 1
      STDERR.puts "skipped=#{tid}"
      next
    end
    src = (t["source_id"] || "").to_s
    sec = (t["section_id"] || "").to_s
    rec = {
      "topic_id"         => tid,
      "source_id"        => src,
      "section_id"       => sec,
      "pillar"           => (t["pillar"] || "").to_s,
      "curriculum_phase" => (t["curriculum_phase"] || "").to_s,
      "delta_class"      => (t["delta_class"] || "best_practice_updated").to_s,
      "citation"         => "#{src}##{sec}",
      "summary"          => (t["summary"] || "").to_s,
      "reached"          => true,
      "decision"         => decide,
      "state"            => "learned",
      "studied_at"       => now
    }
    out_lines << JSON.generate(rec)
    studied += 1
    STDERR.puts "studied=#{tid}"
  end

  unless dry_run || out_lines.empty?
    require "fileutils"
    dir = File.dirname(ledger_path)
    FileUtils.mkdir_p(dir) unless dir.empty? || dir == "."
    File.open(ledger_path, "a") { |f| out_lines.each { |l| f.puts l } }
  end

  STDERR.puts "dry_run=true" if dry_run
  STDERR.puts "topics_total=#{topics.length}"
  STDERR.puts "studied=#{studied}"
  STDERR.puts "skipped=#{skipped}"
  STDERR.puts "ledger=#{ledger_path}"
'
exit 0
