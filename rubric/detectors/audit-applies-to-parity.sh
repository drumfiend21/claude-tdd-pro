#!/usr/bin/env bash
# rubric/detectors/audit-applies-to-parity.sh — ADR-0008 Wave 2 parity-diff gate.
#
# Verifies the applies_to.* migration preserved every rule's enforcement (no language/rule
# silently dropped or re-scoped). For each coding rule it asserts:
#   1. PARITY: the rule's original `detector` is preserved as enforced_by[0] with required:true.
#      (The migration only ADDS 4-axis routing; it never removes the existing enforcement.)
#   2. ROUTABLE: the rule carries a non-empty enforced_by (the composite engine can run it).
# Reports any rule that fails either, with its namespace. Run in /doctor + CI.
#
# CLI: [--root <dir>] [--quiet]
# stderr: per failure `applies-to-parity rule=<id> ns=<ns> reason=<...>`; summary
#         `applies-to-parity status=<green|red> rules=<n> parity_fail=<p> unrouted=<u>`
# Exit: 0 all parity-preserved + routable | 1 violations | 2 usage.

set -uo pipefail
ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: audit-applies-to-parity.sh [--root <dir>] [--quiet]" >&2; exit 0 ;;
    *) echo "audit-applies-to-parity: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

ROOT="$ROOT" QUIET="$QUIET" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]; quiet = ENV["QUIET"] == "1"
  n = 0; parity_fail = 0; unrouted = 0
  Dir[File.join(root, "generated-code-quality-standards", "*", "*.yaml")].sort.each do |f|
    ns = f.split("/")[-2]
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    rules = d["rules"]; next unless rules.is_a?(Array)
    rules.each do |r|
      next unless r.is_a?(Hash) && r["id"]
      n += 1
      eb = r["enforced_by"]
      if !eb.is_a?(Array) || eb.empty?
        unrouted += 1
        STDERR.puts "applies-to-parity rule=#{r["id"]} ns=#{ns} reason=no-enforced_by" unless quiet
        next
      end
      # parity: the original detector must be the first, required enforced_by entry.
      first = eb[0]
      ok = first.is_a?(Hash) && first["tool"] == r["detector"] && first["required"] == true
      unless ok
        parity_fail += 1
        STDERR.puts "applies-to-parity rule=#{r["id"]} ns=#{ns} reason=detector-not-preserved detector=#{r["detector"]} first=#{first.inspect}" unless quiet
      end
    end
  end
  status = (parity_fail.zero? && unrouted.zero?) ? "green" : "red"
  STDERR.puts "applies-to-parity status=#{status} rules=#{n} parity_fail=#{parity_fail} unrouted=#{unrouted}" unless quiet
  exit(status == "green" ? 0 : 1)
'
