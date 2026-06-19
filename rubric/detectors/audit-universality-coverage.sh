#!/usr/bin/env bash
# rubric/detectors/audit-universality-coverage.sh - the apply-by-default coverage gate
# (v1.18 §28.21). Guarantees the operator invariant: every enforced rule from the
# curated first-class sources is APPLIED to all generated software by default, and a
# rule is WITHHELD only with a complete, justified exemption — so nothing slips through.
#
# For every rule in generated-code-quality-standards/<ns>/*.yaml:
#   - no `enforcement` field, or enforcement.mode != "withheld"  -> APPLIED (default, OK)
#   - enforcement.mode == "withheld"  -> requires the full conjunction justification:
#       reason (non-empty) AND bound_to (lang|framework|tech) AND not_general_because.
#     A withheld rule missing any conjunct is REJECTED (an un-justified withhold cannot
#     silently drop a source standard). Forgetting to classify can only ever leave a
#     rule APPLIED (over-enforce), never dropped.
#
# CLI: --root <dir> (default $CLAUDE_PLUGIN_ROOT/generated-code-quality-standards) [--quiet]
# stderr: per offence `universality rule=<id> verdict=incomplete-withhold missing=<csv>`;
#         summary `universality status=<green|red> rules=<n> applied=<a> withheld=<w> bad=<b>`
# Exit: 0 green | 1 an under-justified withhold exists | 2 usage.

set -uo pipefail
ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: audit-universality-coverage.sh [--root <dir>] [--quiet]" >&2; exit 0 ;;
    *) echo "audit-universality-coverage: unknown arg: $1" >&2; exit 2 ;;
  esac
done
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
[ -z "$ROOT" ] && ROOT="$PLUGIN_ROOT/generated-code-quality-standards"
[ ! -d "$ROOT" ] && { echo "audit-universality-coverage: root not found: $ROOT" >&2; exit 2; }

ROOT="$ROOT" QUIET="$QUIET" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]; quiet = ENV["QUIET"] == "1"
  rules = 0; applied = 0; withheld = 0; bad = 0
  Dir[File.join(root, "*", "*.yaml")].sort.each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"] || []).each do |r|
      next unless r.is_a?(Hash) && r["id"]
      rules += 1
      e = r["enforcement"]
      if e.is_a?(Hash) && e["mode"].to_s == "withheld"
        # withhold must carry the complete conjunction justification
        missing = []
        missing << "reason" if e["reason"].to_s.strip.empty?
        missing << "bound_to" if e["bound_to"].to_s.strip.empty?
        missing << "not_general_because" if e["not_general_because"].to_s.strip.empty?
        if missing.empty?
          withheld += 1
        else
          bad += 1
          STDERR.puts "universality rule=#{r["id"]} verdict=incomplete-withhold missing=#{missing.join(",")}" unless quiet
        end
      else
        applied += 1   # default: applied to all generated software
      end
    end
  end
  status = bad.zero? ? "green" : "red"
  STDERR.puts "universality status=#{status} rules=#{rules} applied=#{applied} withheld=#{withheld} bad=#{bad}"
  exit(bad.zero? ? 0 : 1)
'
