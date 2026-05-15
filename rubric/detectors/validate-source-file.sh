#!/usr/bin/env bash
# validate-source-file — validate a source-folder YAML file under
# generated-code-quality-standards/<namespace>/ against the v1.9
# source-file schema, and cross-validate each rule against the
# rubric-rule schema.
#
# Usage:
#   bash validate-source-file.sh <path-to-source-file.yaml>
#
# Per detector contract §2.2:
#   exit 0 → valid (structurally + cross-validated)
#   exit 2 → invalid (errors written to stderr, one per line)
#   exit 1 → tooling error (file missing, ruby/node missing)
#
# Validation phases:
#   1. Structural: validate against schemas/source-file.schema.json
#   2. Per-rule: each rule in `rules:` validates against schemas/rubric-rule.schema.json
#   3. Cross-set: all_set MUST equal exactly the set of rule IDs in rules:
#                 recommended_set MUST be a subset of all_set

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
SOURCE_FILE_SCHEMA="$PLUGIN_ROOT/schemas/source-file.schema.json"
RUBRIC_RULE_SCHEMA="$PLUGIN_ROOT/schemas/rubric-rule.schema.json"
VALIDATOR="$PLUGIN_ROOT/rubric/detectors/lib/validate-json-schema.js"

SOURCE_FILE=""
CHECK_REGISTRY_LINK=0
REGISTRY_PATH=""
CHECK_RECOMMENDED_CONSISTENCY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-registry-link) CHECK_REGISTRY_LINK=1; shift ;;
    --registry) REGISTRY_PATH="$2"; shift 2 ;;
    --check-recommended-consistency) CHECK_RECOMMENDED_CONSISTENCY=1; shift ;;
    -h|--help)
      echo "Usage: validate-source-file.sh <path> [--check-registry-link --registry <path>] [--check-recommended-consistency]" >&2
      exit 0 ;;
    *)
      if [[ -z "$SOURCE_FILE" ]]; then
        SOURCE_FILE="$1"
        shift
      else
        echo "validate-source-file: unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$SOURCE_FILE" ]]; then
  echo "validate-source-file: usage: validate-source-file.sh <path-to-source-file.yaml> [--check-registry-link --registry <path>]" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "validate-source-file: file not found: $SOURCE_FILE" >&2
  exit 1
fi

# E-6: --check-recommended-consistency verifies that recommended_set
# matches exactly the set of rule ids with recommended:true.
if [[ "$CHECK_RECOMMENDED_CONSISTENCY" -eq 1 ]]; then
  SOURCE_FILE="$SOURCE_FILE" node -e '
    const fs = require("fs");
    const c = fs.readFileSync(process.env.SOURCE_FILE, "utf8");
    const recMatch = c.match(/^recommended_set:\s*\[([^\]]*)\]/m);
    const recDeclared = new Set((recMatch ? recMatch[1].split(",") : []).map(s => s.trim()).filter(Boolean));
    const recActual = new Set();
    const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?(?=\n\s*-\s+\{|\n\s*-\s+id:|\nrecommended_set:|\nall_set:|$)/g;
    let m;
    while ((m = ruleRe.exec(c)) !== null) {
      const id = m[1];
      if (/\brecommended:\s*true/.test(m[0])) recActual.add(id);
    }
    const errs = [];
    for (const id of recActual) if (!recDeclared.has(id)) errs.push(`recommended_set inconsistent: rule ${id} has recommended: true but is not in recommended_set`);
    for (const id of recDeclared) if (!recActual.has(id)) errs.push(`recommended_set inconsistent: ${id} listed in recommended_set but rule does not have recommended: true`);
    if (errs.length === 0) process.exit(0);
    errs.forEach(e => process.stderr.write(e + "\n"));
    process.exit(2);
  '
  exit $?
fi

# §2.21 final sentence: file naming MUST be lowercase-kebab-case.
SOURCE_BASENAME=$(basename "$SOURCE_FILE" .yaml)
if [[ ! "$SOURCE_BASENAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "$(basename "$SOURCE_FILE"):1: filename violates lowercase-kebab-case naming (§2.21): $SOURCE_BASENAME" >&2
  echo "filename must use lowercase letters, digits, and hyphens (kebab-case)" >&2
  exit 2
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "validate-source-file: ruby is required for YAML parsing" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "validate-source-file: node is required for schema validation" >&2
  exit 1
fi

for f in "$SOURCE_FILE_SCHEMA" "$RUBRIC_RULE_SCHEMA" "$VALIDATOR"; do
  if [[ ! -f "$f" ]]; then
    echo "validate-source-file: required file missing: $f" >&2
    exit 1
  fi
done

# YAML → JSON via Ruby.
SOURCE_JSON=$(ruby -ryaml -rjson -e '
  begin
    data = YAML.load_file(ARGV[0])
    puts JSON.generate(data)
  rescue => e
    STDERR.puts "validate-source-file: yaml parse error: #{e.message}"
    exit 1
  end
' "$SOURCE_FILE")

if [[ -z "$SOURCE_JSON" ]]; then
  echo "validate-source-file: empty JSON output from YAML conversion" >&2
  exit 1
fi

# Phase 1: structural validation against source-file.schema.json.
STRUCT_ERRS=$(echo "$SOURCE_JSON" | node "$VALIDATOR" "$SOURCE_FILE_SCHEMA" 2>&1)
STRUCT_EXIT=$?

ANY_FAIL=0

if [[ $STRUCT_EXIT -ne 0 ]]; then
  # Prepend file:line: prefix so error format is grep-friendly per detector contract.
  # Also rewrite the missing-source-block message to include "header" terminology
  # consistent with the aggregator's "missing required source: header" output.
  FILE_BASENAME=$(basename "$SOURCE_FILE")
  echo "$STRUCT_ERRS" \
    | sed 's/<root>: missing required field "source"/missing required source: header/' \
    | sed "s|^|${FILE_BASENAME}:1: [structural] |" >&2
  ANY_FAIL=1
fi

# Phase 2: per-rule validation against rubric-rule.schema.json.
# Extract each rule, pipe to validator, accumulate errors.
RULE_COUNT=$(echo "$SOURCE_JSON" | node -e '
  let s = "";
  process.stdin.on("data", d => s += d);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(s);
      const rules = (j && j.rules) || [];
      process.stdout.write(String(rules.length));
    } catch { process.stdout.write("0"); }
  });
')

if [[ "$RULE_COUNT" =~ ^[0-9]+$ ]] && [[ "$RULE_COUNT" -gt 0 ]]; then
  for ((i=0; i<RULE_COUNT; i++)); do
    RULE_JSON=$(echo "$SOURCE_JSON" | node -e '
      let s = "";
      process.stdin.on("data", d => s += d);
      process.stdin.on("end", () => {
        const j = JSON.parse(s);
        process.stdout.write(JSON.stringify(j.rules['"$i"']));
      });
    ')
    RULE_ERRS=$(echo "$RULE_JSON" | node "$VALIDATOR" "$RUBRIC_RULE_SCHEMA" 2>&1)
    RULE_EXIT=$?
    if [[ $RULE_EXIT -ne 0 ]]; then
      RULE_ID=$(echo "$RULE_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.id||"<unknown>");}catch{process.stdout.write("<unparseable>");}});')
      echo "$RULE_ERRS" | sed "s/^/[rule:$RULE_ID] /" >&2
      ANY_FAIL=1
    fi
  done
fi

# Phase 3: cross-set validation (all_set ↔ rules:; recommended_set ⊆ all_set).
CROSS_ERRS=$(echo "$SOURCE_JSON" | node -e '
  let s = "";
  process.stdin.on("data", d => s += d);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(s);
      const rules = (j && j.rules) || [];
      const ruleIds = rules.map(r => (r && r.id)).filter(x => typeof x === "string");
      const allSet = (j && j.all_set) || [];
      const recSet = (j && j.recommended_set) || [];
      const errs = [];
      // all_set MUST equal exactly the set of rule IDs in rules:
      const ruleIdSet = new Set(ruleIds);
      const allSetSet = new Set(allSet);
      for (const id of allSet) {
        if (!ruleIdSet.has(id)) {
          errs.push(`all_set: declares "${id}" but no rule with that id in rules:`);
        }
      }
      for (const id of ruleIds) {
        if (!allSetSet.has(id)) {
          errs.push(`all_set: missing "${id}" which is defined in rules:`);
        }
      }
      // recommended_set MUST be subset of all_set
      for (const id of recSet) {
        if (!allSetSet.has(id)) {
          errs.push(`recommended_set: "${id}" is not a subset of all_set`);
        }
      }
      if (errs.length > 0) {
        for (const e of errs) process.stderr.write("[cross-set] " + e + "\n");
        process.exit(2);
      }
      process.exit(0);
    } catch (e) {
      process.stderr.write("[cross-set] error: " + e.message + "\n");
      process.exit(1);
    }
  });
' 2>&1)
CROSS_EXIT=$?

if [[ $CROSS_EXIT -ne 0 ]]; then
  echo "$CROSS_ERRS" >&2
  ANY_FAIL=1
fi

# §17 G-6 + §2.21: when --check-registry-link is set, verify source.id maps to
# a top-level key in the registry yaml file passed via --registry.
if [[ "$CHECK_REGISTRY_LINK" -eq 1 ]] && [[ -n "$REGISTRY_PATH" ]] && [[ -f "$REGISTRY_PATH" ]]; then
  REGISTRY_CHECK_OUT=$(echo "$SOURCE_JSON" | ruby -ryaml -rjson -e '
    src_id = JSON.parse(STDIN.read)["source"]["id"] rescue nil
    exit 0 if src_id.nil?
    reg = begin; YAML.load_file(ARGV[0]); rescue; nil; end
    if !reg.is_a?(Hash) || !reg.key?(src_id)
      STDERR.puts "[registry-link] source.id \"#{src_id}\" not found as a top-level key in registry: #{ARGV[0]}"
      exit 2
    end
    exit 0
  ' "$REGISTRY_PATH" 2>&1) || ANY_FAIL=1
  [[ -n "$REGISTRY_CHECK_OUT" ]] && echo "$REGISTRY_CHECK_OUT" >&2
fi

if [[ $ANY_FAIL -ne 0 ]]; then
  exit 2
fi
exit 0
