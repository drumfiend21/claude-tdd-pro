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
  # rule-id-driven detectors (cloud + universal-polyglot) carry their own applies-glob
  # in a manifest and are invoked `--rule <id> --root <dir>`. Merge both manifests.
  mf_applies = {}
  %w[cloud-guidance-rules.json universal-pattern-rules.json].each do |mfn|
    mp = File.join(plugin, "rubric", "detectors", mfn)
    next unless File.exist?(mp)
    (JSON.parse(File.read(mp))["rules"] || {}).each { |id, s| mf_applies[id] = s["applies"].to_s }
  end
  RULE_DRIVEN = %w[cloud-guidance-rule.sh universal-pattern-rule.sh]

  # default single file glob per rule namespace when --paths is not supplied
  def ns_glob(id)
    case id
    when /^g-react-/ then "*.tsx"
    when /^g-ts-/, /^g-node-/ then "*.ts"
    when /^g-doc-/ then "*.md"
    else "*"
    end
  end
  def count_files(globs)
    globs.flat_map { |g| Dir.glob(g) }.uniq.select { |p| File.file?(p) }.size
  end

  results = []
  rules.each do |id|
    det = catalog[id]
    unless det
      results << { "rule" => id, "detector" => nil, "verdict" => "unknown_rule", "files_evaluated" => 0, "exit" => 2 }
      next
    end
    det_path = File.join(plugin, "rubric", "detectors", det)
    is_cloud = RULE_DRIVEN.include?(det)
    # scope = full glob string(s) this rule legitimately evaluates, used identically
    # for the file count AND the detector. Rule-driven detectors (cloud IaC, universal
    # polyglot) use their OWN manifest applies-glob (so a cloud rule on a pure-code tree
    # is not_applicable, and a universal rule spans every source language); code
    # detectors use --paths (as given) or the namespace default under root.
    if is_cloud
      globs = (mf_applies[id].to_s.empty? ? ["*"] : mf_applies[id].split(",")).map { |g| File.join(root, "**", g.strip) }
    elsif user_paths.empty?
      globs = [File.join(root, "**", ns_glob(id))]
    else
      globs = user_paths.split(",").map(&:strip)
    end
    files = count_files(globs)

    if files.zero?
      # 0 files matched the rule scope -> not_applicable (NEUTRAL, distinct from pass).
      # This kills the vacuous-green class: "nothing to check" is never a pass.
      results << { "rule" => id, "detector" => det, "verdict" => "not_applicable", "files_evaluated" => 0, "exit" => 0 }
      next
    end

    cmd = is_cloud ? ["bash", det_path, "--rule", id, "--root", root] \
                   : ["bash", det_path, "--paths", (user_paths.empty? ? globs[0] : user_paths)]
    system(*cmd, out: File::NULL, err: File::NULL)
    ec = $?.exitstatus
    verdict = case ec
              when 0 then "pass"          # ran, >=1 file evaluated, 0 findings
              when 1 then "fail"          # ran, >=1 finding
              else "not_enforced"          # had files, detector could not verify (tool/model absent) -> RED, never a pass
              end
    results << { "rule" => id, "detector" => det, "verdict" => verdict, "files_evaluated" => files, "exit" => ec }
  end

  cnt = ->(v) { results.count { |r| r["verdict"] == v } }
  npass, nfail, nna, nun, nunk = cnt["pass"], cnt["fail"], cnt["not_applicable"], cnt["not_enforced"], cnt["unknown_rule"]

  results.each { |r| STDERR.puts "enforce rule=#{r["rule"]} detector=#{r["detector"]} verdict=#{r["verdict"]} files_evaluated=#{r["files_evaluated"]}" }
  status = (nfail.positive? || nunk.positive?) ? "red" : (nun.positive? ? "incomplete" : "green")
  STDERR.puts "enforce status=#{status} pass=#{npass} fail=#{nfail} not_applicable=#{nna} not_enforced=#{nun}"

  if want_json
    puts JSON.generate({ "root" => root, "results" => results,
                         "summary" => { "pass" => npass, "fail" => nfail, "not_applicable" => nna,
                                        "not_enforced" => nun, "unknown_rule" => nunk } })
  end

  # exit 0 iff every rule is pass OR not_applicable; fail/unknown -> 1/2; not_enforced -> 3 (never collapses to success)
  exit 2 if nunk.positive?
  exit 1 if nfail.positive?
  exit 3 if nun.positive?
  exit 0
'
