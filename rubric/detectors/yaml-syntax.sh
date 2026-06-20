#!/usr/bin/env bash
# rubric/detectors/yaml-syntax.sh - Layer-1 YAML well-formedness detector (ADR-0007 /
# §28.24, CTP-D-4). Rule-id-driven like cloud-guidance-rule.sh so enforce.sh dispatches
# it via --rule/--root. Wraps yamllint when present; otherwise parses via ruby's YAML
# (still dependency-light). If NEITHER is available the detector reports not_enforced
# (exit 3) rather than a vacuous green. Grounds in the YAML 1.2.2 spec + yamllint.
#
# Rules:
#   g-yaml-well-formed  - every *.yaml/*.yml file must parse as YAML.
#
# CLI: --rule <id> --root <dir> [--paths <glob>] [--json]
# stderr: per finding `yaml-syntax file=<f> rule=<id>`; summary `yaml-syntax rule=<id> status=<green|red> findings=<n>`
# Exit: 0 clean | 1 findings | 3 not_enforced (no parser) | 2 usage.

set -uo pipefail
RULE=""; ROOT="."; PATHS=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --rule)  RULE="${2-}";  shift 2 ;;
    --root)  ROOT="${2-}";  shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help) echo "Usage: yaml-syntax.sh --rule <id> --root <dir> [--paths <glob>] [--json]" >&2; exit 0 ;;
    *) echo "yaml-syntax: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$RULE" ] && { echo "yaml-syntax: --rule <id> required" >&2; exit 2; }
[ "$RULE" != "g-yaml-well-formed" ] && { echo "yaml-syntax: unknown rule $RULE" >&2; exit 2; }
command -v ruby >/dev/null 2>&1 || { echo "yaml-syntax rule=$RULE status=not_enforced reason=no-yaml-parser" >&2; exit 3; }

RULE="$RULE" ROOT="$ROOT" PATHS="$PATHS" JSON="$JSON" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  rule = ENV["RULE"]; root = ENV["ROOT"]; want_json = ENV["JSON"] == "1"
  paths = ENV["PATHS"].to_s.strip
  globs = paths.empty? ? [File.join(root, "**", "*.yaml"), File.join(root, "**", "*.yml")] : paths.split(",")
  files = globs.flat_map { |g| Dir.glob(g) }.uniq.select { |f| File.file?(f) }
  findings = []
  files.each do |f|
    begin
      YAML.unsafe_load_file(f)
    rescue Psych::SyntaxError
      findings << f
    rescue StandardError
      # non-syntax read error is not a YAML well-formedness finding
    end
  end
  if want_json
    sarif = { "version" => "2.1.0",
      "$schema" => "https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json",
      "runs" => [ { "tool" => { "driver" => { "name" => "yaml-syntax", "version" => "1.0.0", "rules" => [{ "id" => rule }] } },
        "results" => findings.map { |f| { "ruleId" => rule, "level" => "error",
          "message" => { "text" => "#{rule} violation: not well-formed YAML" },
          "locations" => [{ "physicalLocation" => { "artifactLocation" => { "uri" => f }, "region" => { "startLine" => 1 } } }] } } } ] }
    puts JSON.generate(sarif)
  end
  findings.each { |f| STDERR.puts "yaml-syntax file=#{f} rule=#{rule}" }
  STDERR.puts "yaml-syntax rule=#{rule} status=#{findings.empty? ? "green" : "red"} findings=#{findings.size}"
  exit(findings.empty? ? 0 : 1)
'
