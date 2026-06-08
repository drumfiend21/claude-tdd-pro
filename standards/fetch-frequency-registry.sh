#!/usr/bin/env bash
# standards/fetch-frequency-registry.sh — S-22 FETCH-FREQUENCIES.yaml resolver
# (v1.12 §27).
#
# Per §27 S-22: "Top-level .claude-tdd-pro/FETCH-FREQUENCIES.yaml mapping
# per-registry default and per-source override cadence; any-frequency
# resolves here; global default daily."
#
# Per §2.28 resolution order: per-source override -> per-registry default ->
# global default (daily). This is the endpoint the any-frequency shorthand
# (S-20 poll-scheduler) defers to.
#
# File shape (operator-editable):
#   default: daily              # global default (optional; falls back to daily)
#   registries:                 # per-registry default (optional)
#     standards: 12h
#     pr-corpus: daily
#     compliance: weekly
#   sources:                    # per-source override — wins (optional)
#     aws-well-architected: 5m
#
# CLI:
#   --source-id <id>   (required)
#   --registry <name>  standards | pr-corpus | compliance (default standards)
#   --file <path>      FETCH-FREQUENCIES.yaml (default
#                      .claude-tdd-pro/FETCH-FREQUENCIES.yaml)
#
# stdout: the resolved concrete cadence (for programmatic capture, e.g. by
#         the S-20 poll-scheduler any-frequency handoff).
# stderr: resolved_frequency=<token> resolution=<tier> interval_ms=<N>
#         (tier: per-source-override|per-registry-default|global-default|fallback-daily)
#         valid=false invalid_cadence=<token> resolution=<tier>  (on bad value)
#
# Exit: 0 valid / 2 invalid resolved cadence or usage error.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
# shellcheck disable=SC1091
. "$PLUGIN_ROOT/lib/fetch-frequency-grammar.sh"

SOURCE_ID=""
REGISTRY="standards"
FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source-id) SOURCE_ID="${2-}"; shift 2 ;;
    --registry)  REGISTRY="${2-}";  shift 2 ;;
    --file)      FILE="${2-}";      shift 2 ;;
    -h|--help)
      echo "Usage: fetch-frequency-registry.sh --source-id <id> [--registry standards|pr-corpus|compliance] [--file <path>]" >&2
      exit 0
      ;;
    *) echo "fetch-frequency-registry: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SOURCE_ID" ]; then
  echo "fetch-frequency-registry: --source-id is required" >&2
  exit 2
fi
case "$REGISTRY" in
  standards|pr-corpus|compliance) ;;
  *) echo "fetch-frequency-registry: unknown registry: $REGISTRY (expected standards|pr-corpus|compliance)" >&2; exit 2 ;;
esac

FF="$FILE"
if [ -z "$FF" ]; then FF=".claude-tdd-pro/FETCH-FREQUENCIES.yaml"; fi

# Resolve per §2.28 order: per-source override -> per-registry default ->
# global default -> daily fallback. YAML parsing via ruby Psych (established
# repo pattern); robust to a missing file or non-map sections.
res=$(SRC="$SOURCE_ID" REG="$REGISTRY" FF="$FF" ruby -ryaml -e '
  ff = ENV["FF"]
  cfg = File.exist?(ff) ? (YAML.load_file(ff) || {}) : {}
  cfg = {} unless cfg.is_a?(Hash)
  sources    = cfg["sources"]
  registries = cfg["registries"]
  src = sources.is_a?(Hash) ? sources[ENV["SRC"]] : nil
  reg = registries.is_a?(Hash) ? registries[ENV["REG"]] : nil
  glob = cfg["default"]
  if src && !src.to_s.empty?
    print "#{src}\tper-source-override"
  elsif reg && !reg.to_s.empty?
    print "#{reg}\tper-registry-default"
  elsif glob && !glob.to_s.empty?
    print "#{glob}\tglobal-default"
  else
    print "daily\tfallback-daily"
  end
')

resolved=$(printf '%s' "$res" | cut -f1)
tier=$(printf '%s' "$res" | cut -f2)

# Validate the resolved cadence against the shared §2.28 grammar.
if ! parsed=$(ff_resolve_cadence "$resolved"); then
  echo "valid=false invalid_cadence=$resolved resolution=$tier" >&2
  exit 2
fi
set -- $parsed
interval_ms="$1"

echo "resolved_frequency=$resolved" >&2
echo "resolution=$tier" >&2
echo "interval_ms=$interval_ms" >&2

# stdout: the bare resolved cadence for programmatic capture.
printf '%s\n' "$resolved"
exit 0
