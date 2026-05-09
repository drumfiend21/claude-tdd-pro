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

if [[ $# -ne 1 ]]; then
  echo "validate-source-file: usage: validate-source-file.sh <path-to-source-file.yaml>" >&2
  exit 1
fi

SOURCE_FILE="$1"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "validate-source-file: file not found: $SOURCE_FILE" >&2
  exit 1
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
  echo "$STRUCT_ERRS" | sed 's/^/[structural] /' >&2
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
          errs.push(`recommended_set: "${id}" is not in all_set`);
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

if [[ $ANY_FAIL -ne 0 ]]; then
  exit 2
fi
exit 0
