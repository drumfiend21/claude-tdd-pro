#!/usr/bin/env bash
# rubric/detectors/cloud-guidance-rule.sh - detector for promoted cloud/governance
# guidance rules (§2.2 detector contract; v1.18 §28.15 Layer-A activation).
#
# Enforces a single promoted cloud/EO guidance rule (require/forbid a token in the
# files a rule applies to) at write-time, the same way ESLint runs a rule. The rule's
# check (token, mode, applies-glob) is read from the generated manifest
# rubric/detectors/cloud-guidance-rules.json (single source of truth, produced by
# commands/promote-cloud-rules.sh alongside the §2.1 rule files). Each rule cites an
# authoritative source (provenance in its rule file).
#
# CLI: --rule <rule-id> [--paths <glob>] [--root <dir>] [--json]
# stderr (text): per finding `cloud-guidance file=<path> rule=<id> mode=<m> token=<t>`;
#                summary `cloud-guidance rule=<id> status=<green|red> findings=<n>`
# Exit: 0 clean | 1 findings | 2 usage/tooling error.

set -uo pipefail

RULE=""; PATHS=""; ROOT="."; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --root)  ROOT="${2-}";  shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: cloud-guidance-rule.sh --rule <id> [--paths <glob>] [--root <dir>] [--json]" >&2; exit 0 ;;
    *) echo "cloud-guidance-rule: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "cloud-guidance-rule: --rule <id> required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
MANIFEST="$PLUGIN_ROOT/rubric/detectors/cloud-guidance-rules.json"
# config-guidance-rules.json is the SECOND manifest (PROPOSAL-003 / §28.24 config &
# markup namespaces). Both feed the same require/forbid-token check; merged here so the
# two generators (promote-cloud-rules.sh / promote-config-rules.sh) never clobber.
CONFIG_MANIFEST="$PLUGIN_ROOT/rubric/detectors/config-guidance-rules.json"
[ -f "$MANIFEST" ] || { echo "cloud-guidance-rule: manifest missing: $MANIFEST" >&2; exit 2; }

RULE="$RULE" PATHS="$PATHS" ROOT="$ROOT" JSON="$JSON" MANIFEST="$MANIFEST" CONFIG_MANIFEST="$CONFIG_MANIFEST" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  rule = ENV["RULE"]; root = ENV["ROOT"]; want_json = ENV["JSON"] == "1"
  m = JSON.parse(File.read(ENV["MANIFEST"]))
  all_rules = (m["rules"] || {})
  cm = ENV["CONFIG_MANIFEST"].to_s
  if !cm.empty? && File.exist?(cm)
    (JSON.parse(File.read(cm))["rules"] || {}).each { |k, v| all_rules[k] ||= v }
  end
  spec = all_rules[rule]
  unless spec
    STDERR.puts "cloud-guidance-rule: unknown rule #{rule}"; exit 2
  end
  token = spec["token"].to_s; mode = spec["mode"].to_s
  applies = spec["applies"].to_s.empty? ? "*" : spec["applies"]
  globs = ENV["PATHS"].to_s.empty? ? applies.split(",") : ENV["PATHS"].split(",")

  files = []
  globs.each do |g|
    g = g.strip
    files.concat(Dir.glob(File.join(root, "**", g)))  # bare pattern under root (tree scan)
    files.concat(Dir.glob(g))                          # direct path/glob (absolute or cwd-relative,
                                                        # e.g. a single file handed by enforce-file.sh)
  end
  files = files.uniq.select { |f| File.file?(f) }

  findings = []
  files.each do |f|
    content = (File.read(f) rescue "")
    present = content.include?(token)
    bad = (mode == "forbid") ? present : !present
    findings << f if bad
  end

  if want_json
    out = { "rule" => rule, "mode" => mode, "token" => token,
            "status" => (findings.empty? ? "green" : "red"),
            "findings" => findings.map { |f| { "file" => f } } }
    puts JSON.generate(out)
  end
  findings.each { |f| STDERR.puts "cloud-guidance file=#{f} rule=#{rule} mode=#{mode} token=#{token}" }
  STDERR.puts "cloud-guidance rule=#{rule} status=#{findings.empty? ? "green" : "red"} findings=#{findings.size}"
  exit(findings.empty? ? 0 : 1)
'
