#!/usr/bin/env bash
# rubric/detectors/universal-pattern-rule.sh - polyglot detector for a generally-
# applicable, language-agnostic standard (v1.18 §28.21). Enforces ONE rule's pattern
# set across ANY source language by matching extended-regex tokens, so a standard like
# "no hardcoded secrets" applies to .py / .go / .rs / .java / .ts / … alike. Rule-id
# driven (like cloud-guidance-rule.sh): the rule's {mode, patterns, applies, message}
# come from the generated manifest rubric/detectors/universal-pattern-rules.json
# (single source of truth, produced with the §2.1 rule files by promote-universal-rules.sh).
#
# CLI: --rule <id> --root <dir> [--paths <glob>] [--json]
# stderr: per finding `universal-pattern file=<f> rule=<id> mode=<m>`;
#         summary `universal-pattern rule=<id> status=<green|red> findings=<n>`
# Exit: 0 clean | 1 findings | 2 usage.

set -uo pipefail
RULE=""; ROOT="."; PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --root)  ROOT="${2-}";  shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: universal-pattern-rule.sh --rule <id> --root <dir> [--paths <glob>] [--json]" >&2; exit 0 ;;
    *) echo "universal-pattern-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "universal-pattern-rule: --rule <id> required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
MANIFEST="$PLUGIN_ROOT/rubric/detectors/universal-pattern-rules.json"
[ -f "$MANIFEST" ] || { echo "universal-pattern-rule: manifest missing: $MANIFEST" >&2; exit 2; }

RULE="$RULE" ROOT="$ROOT" PATHS="$PATHS" JSON="$JSON" MANIFEST="$MANIFEST" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  rule = ENV["RULE"]; root = ENV["ROOT"]; want_json = ENV["JSON"] == "1"
  m = JSON.parse(File.read(ENV["MANIFEST"]))
  spec = (m["rules"] || {})[rule]
  unless spec
    STDERR.puts "universal-pattern-rule: unknown rule #{rule}"; exit 2
  end
  mode = spec["mode"].to_s
  patterns = (spec["patterns"] || []).map(&:to_s)
  applies = spec["applies"].to_s.empty? ? ["*"] : spec["applies"].split(",")
  globs = ENV["PATHS"].to_s.empty? ? applies.map { |g| File.join(root, "**", g.strip) } \
                                   : ENV["PATHS"].split(",")
  files = globs.flat_map { |g| Dir.glob(g) }.uniq.select { |f| File.file?(f) }

  rx = patterns.empty? ? nil : Regexp.new(patterns.join("|"), Regexp::IGNORECASE)
  findings = []
  files.each do |f|
    text = (File.read(f) rescue "")
    present = rx && (text =~ rx)
    bad = (mode == "forbid") ? !!present : !present
    findings << f if bad
  end

  if want_json
    puts JSON.generate("rule" => rule, "mode" => mode,
                       "status" => (findings.empty? ? "green" : "red"),
                       "findings" => findings.map { |f| { "file" => f } })
  end
  findings.each { |f| STDERR.puts "universal-pattern file=#{f} rule=#{rule} mode=#{mode}" }
  STDERR.puts "universal-pattern rule=#{rule} status=#{findings.empty? ? "green" : "red"} findings=#{findings.size}"
  exit(findings.empty? ? 0 : 1)
'
