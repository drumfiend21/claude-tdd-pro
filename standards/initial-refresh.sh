#!/usr/bin/env bash
# standards/initial-refresh.sh - START the source-refresh loop on install (and on each
# session start), so the plugin begins keeping its standards/rules/patterns fresh from
# the moment it is installed (v1.18 §28.23).
#
# What it does (idempotent, network-tolerant, non-fatal):
#   1. Seeds the freshness baseline: ensures .claude-tdd-pro/standards-last-fetch/<id>.json
#      exists for every source in the catalogs (content_hash + fetched_at). This is what
#      STARTS freshness tracking — until it exists, nothing has a baseline to diff against.
#   2. Runs the daily per-source refresh (S-17 auto-refresh-daily) best-effort: live
#      conditional-GET fetches happen when the environment permits network egress; offline
#      degrades to cached and the loop simply retries next session (never fails install).
#   3. Runs universal-coverage-sync (§28.22) so universal coverage is current from day one.
#
# Invoked by: scripts/install.sh (background, on install) AND the SessionStart hook
# (first-use-of-day). Live polling cadence thereafter is the in-use poll-scheduler (S-20).
#
# CLI: [--root <dir>] [--state-dir <dir>] [--now <iso>] [--quiet]   exit 0 (always non-fatal).

set -uo pipefail
ROOT=""; STATE_DIR=""; NOW=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2-}";      shift 2 ;;
    --state-dir) STATE_DIR="${2-}"; shift 2 ;;
    --now)       NOW="${2-}";       shift 2 ;;
    --quiet)     QUIET=1; shift ;;
    -h|--help) echo "Usage: initial-refresh.sh [--root <dir>] [--state-dir <dir>] [--now <iso>] [--quiet]" >&2; exit 0 ;;
    *) echo "initial-refresh: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
[ -z "$STATE_DIR" ] && STATE_DIR="$ROOT/.claude-tdd-pro/standards-last-fetch"
[ -z "$NOW" ] && NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 2026-06-15T00:00:00Z)"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# 1) Seed the freshness baseline from the committed source catalog (idempotent).
SEEDED=$(ROOT="$ROOT" STATE_DIR="$STATE_DIR" NOW="$NOW" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  root=ENV["ROOT"]; sd=ENV["STATE_DIR"]; now=ENV["NOW"]
  sources = {}
  # reading-source + rule-file headers
  Dir[File.join(root,"generated-code-quality-standards","*","*.yaml")].each do |f|
    d=(YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    s=d["source"]; sources[s["id"]] ||= s["content_hash"].to_s if s.is_a?(Hash) && s["id"]
  end
  # source catalogs (S-1 + cloud + EO)
  Dir[File.join(root,"standards","*-sources.yaml")].each do |f|
    arr=(YAML.unsafe_load_file(f) rescue nil); next unless arr.is_a?(Array)
    arr.each { |e| sources[e["id"]] ||= (e["content_hash"]||"unfetched").to_s if e.is_a?(Hash) && e["id"] }
  end
  seeded=0
  sources.each do |id,hash|
    marker=File.join(sd,"#{id}.json")
    next if File.exist?(marker)
    File.write(marker, JSON.generate("id"=>id,"content_hash"=>(hash.empty? ? "unfetched" : hash),
                                     "fetched_at"=>now,"freshness"=>"bootstrap-seeded"))
    seeded+=1
  end
  puts seeded
' 2>/dev/null || echo 0)

# 2) Best-effort live daily refresh (S-17), BACKGROUNDED so this never blocks session
# start. Never fails; offline -> cached, retried next session.
if [ -x "$ROOT/standards/auto-refresh-daily.sh" ]; then
  ( bash "$ROOT/standards/auto-refresh-daily.sh" --now "$NOW" >/dev/null 2>&1 || true ) &
  disown 2>/dev/null || true
fi

# 3) Bring universal coverage current (§28.22). Idempotent, never fatal.
if [ -x "$ROOT/commands/universal-coverage-sync.sh" ]; then
  bash "$ROOT/commands/universal-coverage-sync.sh" --root "$ROOT" --state-dir "$STATE_DIR" --no-promote --now "$NOW" >/dev/null 2>&1 || true
fi

# 4) Refresh the ADR-0008 4-axis canonical vocabulary mirrors (§28.28 Wave 1). Backgrounded,
# best-effort: Linguist is live-fetched, the curated axes are re-emitted; offline -> keep mirror.
if [ -x "$ROOT/vendor/canonical-vocabulary/refresh-vocabulary.sh" ]; then
  ( bash "$ROOT/vendor/canonical-vocabulary/refresh-vocabulary.sh" >/dev/null 2>&1 || true ) &
  disown 2>/dev/null || true
fi

[ "$QUIET" -eq 1 ] || echo "initial-refresh status=armed seeded=${SEEDED:-0} state_dir=$STATE_DIR" >&2
exit 0
