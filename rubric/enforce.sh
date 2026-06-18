#!/usr/bin/env bash
# rubric/enforce.sh - run CTP detectors against an EXTERNAL application working tree,
# scoped to a rule set (v1.18 §28.17; "Fix E" from the GCTP install/kata feedback).
#
# This is the stable contract surface a downstream consumer (e.g. GCTP's
# enforce-standards.sh) calls to ENFORCE — not merely claim — standards on an app it
# built. It generalizes the proven `cloud-guidance-rule.sh --rule <id> --root <dir>`
# pattern up to a dispatcher over ALL detectors, keyed by the rule IDs as they appear
# in `generated-code-quality-standards/` (= the catalog that syncs into a consumer's
# `active.json`), NOT the RUBRIC.yaml IDs (the bare prefixes collide: `g-ts-001` is
# `no-any` here but `g-ts-001-naming-style` in RUBRIC.yaml).
#
# TRI-STATE per rule (a consumer must tell clean from un-run): each rule reports
# pass | fail | not_enforced. not_enforced = the detector could not actually run
# (tool absent / not-applicable / deferred-to-agent — detector exit 3 or other),
# and MUST NOT be read as a pass.
#
# CLI:
#   --root <dir>            the external app tree to evaluate (required)
#   --rule <id>             a rule id to enforce (repeatable)
#   --rules <id,id,...>     comma list of rule ids
#   --paths <glob>          override the file glob handed to code detectors
#   --json                  emit a machine-readable report to stdout
# stderr: per rule  `enforce rule=<id> detector=<det> verdict=<pass|fail|not_enforced>`
#         summary   `enforce status=<green|red|incomplete> pass=<n> fail=<n> not_enforced=<n>`
# Exit: 0 all pass | 1 >=1 fail | 3 no fail but >=1 not_enforced | 2 usage / unknown rule.

set -uo pipefail

ROOT=""; PATHS=""; JSON=0; RULES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root)  ROOT="${2-}";  shift 2 ;;
    --rule)  RULES+=("${2-}"); shift 2 ;;
    --rules) IFS=',' read -r -a _r <<<"${2-}"; RULES+=("${_r[@]}"); shift 2 ;;
    --paths) PATHS="${2-}"; shift 2 ;;
    --json)  JSON=1; shift ;;
    -h|--help)
      echo "Usage: enforce.sh --root <app-dir> --rule <id> [--rule <id>...] | --rules <csv> [--paths <glob>] [--json]" >&2
      exit 0 ;;
    *) echo "enforce: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && { echo "enforce: --root <app-dir> required" >&2; exit 2; }
[ ! -d "$ROOT" ] && { echo "enforce: root not a directory: $ROOT" >&2; exit 2; }
[ ${#RULES[@]} -eq 0 ] && { echo "enforce: at least one --rule / --rules required" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

ROOT="$ROOT" PATHS="$PATHS" JSON="$JSON" PLUGIN_ROOT="$PLUGIN_ROOT" RULES_CSV="$(IFS=,; echo "${RULES[*]}")" \
ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]; plugin = ENV["PLUGIN_ROOT"]; want_json = ENV["JSON"] == "1"
  user_paths = ENV["PATHS"].to_s
  rules = ENV["RULES_CSV"].split(",").reject(&:empty?)

  # id -> detector, from generated-code-quality-standards/ (the catalog a consumer
  # holds via active.json) -- NOT RUBRIC.yaml.
  catalog = {}
  Dir[File.join(plugin, "generated-code-quality-standards", "*", "*.yaml")].each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"] || []).each { |r| catalog[r["id"]] = r["detector"] if r.is_a?(Hash) && r["id"] && r["detector"] }
  end

  # default file glob per rule namespace when --paths is not supplied
  def default_glob(root, id)
    case id
    when /^g-react-/ then "#{root}/**/*.tsx"
    when /^g-ts-/, /^g-node-/ then "#{root}/**/*.ts"
    else "#{root}/**/*"
    end
  end

  results = []
  rules.each do |id|
    det = catalog[id]
    unless det
      results << { "rule" => id, "detector" => nil, "verdict" => "unknown_rule", "exit" => 2 }
      next
    end
    det_path = File.join(plugin, "rubric", "detectors", det)
    if det == "cloud-guidance-rule.sh"
      # the working external-tree-by-rule-id precedent: --rule <id> --root <dir>
      cmd = ["bash", det_path, "--rule", id, "--root", root]
    else
      glob = user_paths.empty? ? default_glob(root, id) : user_paths
      cmd = ["bash", det_path, "--paths", glob]
    end
    system(*cmd, out: File::NULL, err: File::NULL)
    ec = $?.exitstatus
    verdict = case ec
              when 0 then "pass"
              when 1 then "fail"
              else "not_enforced"   # 3 = skip/not-applicable/deferred, 2 = tool/usage -> could not enforce
              end
    results << { "rule" => id, "detector" => det, "verdict" => verdict, "exit" => ec }
  end

  npass = results.count { |r| r["verdict"] == "pass" }
  nfail = results.count { |r| r["verdict"] == "fail" }
  nunk  = results.count { |r| r["verdict"] == "unknown_rule" }
  nun   = results.count { |r| r["verdict"] == "not_enforced" }

  results.each { |r| STDERR.puts "enforce rule=#{r["rule"]} detector=#{r["detector"]} verdict=#{r["verdict"]}" }
  status = nfail.zero? && nun.zero? && nunk.zero? ? "green" : (nfail.positive? || nunk.positive? ? "red" : "incomplete")
  STDERR.puts "enforce status=#{status} pass=#{npass} fail=#{nfail} not_enforced=#{nun}"

  if want_json
    puts JSON.generate({ "root" => root, "results" => results,
                         "summary" => { "pass" => npass, "fail" => nfail, "not_enforced" => nun, "unknown_rule" => nunk } })
  end

  exit 2 if nunk.positive?
  exit 1 if nfail.positive?
  exit 3 if nun.positive?
  exit 0
'
