#!/usr/bin/env bash
# commands/universal-coverage-sync.sh - keep universal coverage current with the daily
# source refresh, minimizing redundant effort (v1.18 §28.22).
#
# Problem: standards come from live URLs the plugin refreshes (~24h). Re-deriving every
# g-universal rule on every refresh would be wasteful. This sync makes the work
# proportional to actual upstream change, composing the existing freshness machinery:
#   - S-21 conditional-GET / content_hash: a source whose hash is UNCHANGED since it was
#     last processed is SKIPPED entirely (zero work) — the redundancy killer.
#   - catalog-as-data (§28.22): promotion is deterministic from
#     standards/universal-standards-catalog.json, so a CHANGED source is re-promoted for
#     free (provenance/rules re-stamped) with no human re-authoring of known principles.
#   - S-5 diff: a CHANGED source is flagged `needs-classification` so an agent reviews
#     only its NEW sections for genuinely-new universal principles (the sole real work,
#     gated to actual change). New principles are appended to the catalog -> next sync
#     promotes them deterministically.
#   - resumable ledger (S-25 pattern): standards/universal-coverage-ledger.jsonl records
#     the processed content_hash per source, so a second run with no change is a no-op.
#
# CLI: [--root <dir>] [--state-dir <dir>] [--ledger <path>] [--now <iso>] [--dry-run]
#   --state-dir : where per-source live freshness lives (<id>.json carrying content_hash);
#                 default .claude-tdd-pro/standards-last-fetch (the §2.29 S-21 state).
# stderr: per source `universal-coverage-sync source=<id> status=<unchanged-skipped|changed-repromoted>`;
#         changed sources also `universal-coverage-sync source=<id> needs-classification=review-new-sections`;
#         summary `universal-coverage-sync processed=<n> unchanged=<m> changed=<k> needs_classification=<k>`
# Exit: 0 sync ran | 2 usage.

set -uo pipefail
ROOT=""; STATE_DIR=""; LEDGER=""; NOW=""; DRY=0; NO_PROMOTE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2-}";      shift 2 ;;
    --state-dir) STATE_DIR="${2-}"; shift 2 ;;
    --ledger)    LEDGER="${2-}";    shift 2 ;;
    --now)       NOW="${2-}";       shift 2 ;;
    --dry-run)   DRY=1; shift ;;
    --no-promote) NO_PROMOTE=1; shift ;;
    -h|--help) echo "Usage: universal-coverage-sync.sh [--root <dir>] [--state-dir <dir>] [--ledger <path>] [--now <iso>] [--dry-run] [--no-promote]" >&2; exit 0 ;;
    *) echo "universal-coverage-sync: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$STATE_DIR" ] && STATE_DIR="$ROOT/.claude-tdd-pro/standards-last-fetch"
[ -z "$LEDGER" ] && LEDGER="$ROOT/standards/universal-coverage-ledger.jsonl"
[ -z "$NOW" ] && NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 2026-06-15T00:00:00Z)"
CATALOG="$ROOT/standards/universal-standards-catalog.json"
[ -f "$CATALOG" ] || { echo "universal-coverage-sync: catalog not found: $CATALOG" >&2; exit 2; }

CHANGED=$(ROOT="$ROOT" STATE_DIR="$STATE_DIR" LEDGER="$LEDGER" NOW="$NOW" DRY="$DRY" CATALOG="$CATALOG" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  root=ENV["ROOT"]; state_dir=ENV["STATE_DIR"]; ledger=ENV["LEDGER"]; now=ENV["NOW"]; dry=ENV["DRY"]=="1"
  cat = JSON.parse(File.read(ENV["CATALOG"]))
  principles = cat["principles"] || []

  # distinct sources -> {catalog_hash, rule_ids}
  sources = {}
  principles.each do |p|
    s = p["source"].to_s; next if s.empty?
    (sources[s] ||= { "catalog_hash" => p["source_content_hash"].to_s, "rule_ids" => [] })["rule_ids"] << p["id"]
  end

  # last processed hash per source from the resumable ledger (most recent wins)
  last = {}
  if File.exist?(ledger)
    File.foreach(ledger) do |line|
      e = (JSON.parse(line) rescue nil); next unless e.is_a?(Hash) && e["source"]
      last[e["source"]] = e["content_hash"].to_s
    end
  end

  def live_hash(state_dir, src)
    f = File.join(state_dir, "#{src}.json")
    return nil unless File.exist?(f)
    d = (JSON.parse(File.read(f)) rescue nil)
    d.is_a?(Hash) ? d["content_hash"].to_s : nil
  end

  changed = 0; unchanged = 0; needs = 0; new_ledger = []
  sources.sort.each do |src, info|
    baseline = last[src].to_s.empty? ? info["catalog_hash"] : last[src]
    live = live_hash(state_dir, src)
    # no live state -> nothing fetched newer -> unchanged
    if live.nil? || live == baseline
      unchanged += 1
      STDERR.puts "universal-coverage-sync source=#{src} status=unchanged-skipped"
      new_ledger << { "source" => src, "content_hash" => baseline, "status" => "unchanged-skipped",
                      "rule_ids" => info["rule_ids"], "synced_at" => now }
    else
      changed += 1; needs += 1
      STDERR.puts "universal-coverage-sync source=#{src} status=changed-repromoted"
      STDERR.puts "universal-coverage-sync source=#{src} needs-classification=review-new-sections"
      new_ledger << { "source" => src, "content_hash" => live, "status" => "changed-repromoted",
                      "rule_ids" => info["rule_ids"], "synced_at" => now }
    end
  end

  unless dry
    File.open(ledger, "a") { |fh| new_ledger.each { |e| fh.puts JSON.generate(e) } }
  end
  STDERR.puts "universal-coverage-sync processed=#{sources.size} unchanged=#{unchanged} changed=#{changed} needs_classification=#{needs}"
  puts changed
')

# A changed source means an upstream delta -> re-promote deterministically (free,
# re-stamps known principles). Only genuinely-new principles (flagged
# needs-classification above) require an agent to append to the catalog.
if [ "${CHANGED:-0}" -gt 0 ] && [ "$DRY" -eq 0 ] && [ "$NO_PROMOTE" -eq 0 ]; then
  bash "$ROOT/commands/promote-universal-rules.sh" --root "$ROOT" >/dev/null 2>&1 || true
fi
exit 0
