#!/usr/bin/env bash
# commands/cloud-conventions.sh - S-30 cloud-architecture convention enforcement
# (v1.12 §27.13).
#
# Enforces the SYNTAX and PATTERNING of cloud-architecture software development
# against grounded convention rulesets. Every rule cites a best-practice source
# (the S-30 engineering catalog or the S-23 architecture catalog); a rule whose
# source is not in any catalog is REJECTED (cite-or-decline). This extends the
# cloud-architect build (S-29) so the architecture is not only structurally
# conformant but written to world-class convention.
#
# A rule: { id, source_id, kind (syntax|patterning), mode (require|forbid),
#           token, message }. require -> token MUST appear in the IaC;
# forbid -> token MUST NOT appear.
#
# CLI:
#   --tool <terraform|bicep|cloudformation>   IaC tool (or read from --unit)
#   --iac <file>            IaC file to lint
#   --unit <id> --build-dir <dir>   lint a build unit's IaC (reads unit.json)
#   --ruleset <path>        rules (default standards/cloud-conventions/<tool>.yaml)
#   --catalog <path>        S-23 catalog (default cloud-architecture-sources.yaml)
#   --eng-catalog <path>    S-30 catalog (default cloud-engineering-sources.yaml)
#
# stderr: per violation `violation=<rule_id> source=<source_id> kind=<k>`;
#         summary `conventions=<green|red>` and `convention_violations=<n>`.
# Exit: 0 green / 1 red (violations) / 2 usage or ungrounded-rule error.

set -uo pipefail

TOOL=""; IAC=""; UNIT=""; BUILD_DIR=""; RULESET=""; CATALOG=""; ENG_CATALOG=""; EO_CATALOG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)        TOOL="${2-}";        shift 2 ;;
    --iac)         IAC="${2-}";         shift 2 ;;
    --unit)        UNIT="${2-}";        shift 2 ;;
    --build-dir)   BUILD_DIR="${2-}";   shift 2 ;;
    --ruleset)     RULESET="${2-}";     shift 2 ;;
    --catalog)     CATALOG="${2-}";     shift 2 ;;
    --eng-catalog) ENG_CATALOG="${2-}"; shift 2 ;;
    --eo-catalog)  EO_CATALOG="${2-}";  shift 2 ;;
    -h|--help)
      echo "Usage: cloud-conventions.sh --tool <t> --iac <file> | --unit <id> --build-dir <dir> [--ruleset <path>] [--eo-catalog <path>]" >&2
      exit 0
      ;;
    *) echo "cloud-conventions: unknown arg: $1" >&2; exit 2 ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { # echo first existing of: $1, $PLUGIN_ROOT/$1
  if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi
}
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ -z "$ENG_CATALOG" ]; then ENG_CATALOG="standards/cloud-engineering-sources.yaml"; fi
# v1.18 §28.11: import the EO security-governance catalog (S-54) as an additional
# grounding source so EO-grounded convention rules pass cite-or-decline. Additive —
# loading a third catalog only EXPANDS the grounded id set; it never makes a
# previously-grounded rule ungrounded (no-regression).
if [ -z "$EO_CATALOG" ]; then EO_CATALOG="standards/eo-security-sources.yaml"; fi
CATALOG=$(resolve "$CATALOG"); ENG_CATALOG=$(resolve "$ENG_CATALOG"); EO_CATALOG=$(resolve "$EO_CATALOG")

TOOL="$TOOL" IAC="$IAC" UNIT="$UNIT" BUILD_DIR="$BUILD_DIR" RULESET="$RULESET" \
CATALOG="$CATALOG" ENG_CATALOG="$ENG_CATALOG" EO_CATALOG="$EO_CATALOG" PLUGIN_ROOT="$PLUGIN_ROOT" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  tool=ENV["TOOL"]; iac=ENV["IAC"]; unit=ENV["UNIT"]; build_dir=ENV["BUILD_DIR"]
  ruleset=ENV["RULESET"]; catalog=ENV["CATALOG"]; eng=ENV["ENG_CATALOG"]; eo=ENV["EO_CATALOG"]; root=ENV["PLUGIN_ROOT"]

  # Resolve the IaC file + tool from a build unit when --unit is given.
  if !unit.empty?
    udir = "#{build_dir}/#{unit}"
    upath = "#{udir}/unit.json"
    unless File.exist?(upath)
      STDERR.puts "cloud-conventions: no build unit at #{udir}"; exit 2
    end
    u = JSON.parse(File.read(upath))
    tool = u["tool"].to_s if tool.empty?
    iac  = "#{udir}/#{u["iac_file"]}" if iac.empty?
  end

  if tool.empty?
    STDERR.puts "cloud-conventions: --tool is required (or --unit)"; exit 2
  end
  unless %w[terraform bicep cloudformation].include?(tool)
    STDERR.puts "cloud-conventions: invalid tool #{tool}"; exit 2
  end
  if iac.empty?
    STDERR.puts "cloud-conventions: --iac <file> is required (or --unit)"; exit 2
  end

  # Resolve the ruleset.
  if ruleset.empty?
    cand = "standards/cloud-conventions/#{tool}.yaml"
    ruleset = File.exist?(cand) ? cand : "#{root}/#{cand}"
  end
  unless File.exist?(ruleset)
    STDERR.puts "cloud-conventions: ruleset not found: #{ruleset}"; exit 2
  end
  rules = begin; YAML.unsafe_load_file(ruleset); rescue; nil; end
  unless rules.is_a?(Array)
    STDERR.puts "cloud-conventions: ruleset is not a list of rules"; exit 2
  end

  # Grounded source ids = ids from the architecture (S-23), engineering (S-30/S-31),
  # AND the EO security-governance (S-54, §28.11) catalogs.
  grounded = {}
  [catalog, eng, eo].each do |c|
    next unless File.exist?(c)
    doc = begin; YAML.unsafe_load_file(c); rescue; nil; end
    next unless doc.is_a?(Array)
    doc.each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end

  # Cite-or-decline: reject any rule whose source is not grounded.
  ungrounded = rules.select { |r| r.is_a?(Hash) && !grounded[r["source_id"]] }
  unless ungrounded.empty?
    ungrounded.each { |r| STDERR.puts "ungrounded_rule=#{r["id"]} source=#{r["source_id"]}" }
    STDERR.puts "conventions=error"
    exit 2
  end

  unless File.exist?(iac)
    STDERR.puts "cloud-conventions: IaC file not found: #{iac}"; exit 2
  end
  content = File.read(iac)

  violations = []
  rules.each do |r|
    next unless r.is_a?(Hash) && r["token"]
    present = content.include?(r["token"].to_s)
    bad = (r["mode"] == "forbid") ? present : !present
    violations << r if bad
  end

  violations.each do |r|
    STDERR.puts "violation=#{r["id"]} source=#{r["source_id"]} kind=#{r["kind"]}"
  end
  if violations.empty?
    STDERR.puts "conventions=green"
    STDERR.puts "convention_violations=0"
    exit 0
  else
    STDERR.puts "conventions=red"
    STDERR.puts "convention_violations=#{violations.length}"
    exit 1
  end
'
exit $?
