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
CHECK_HISTORY_APPEND_ONLY=0
VSF_NOW=""
VSF_MAX_AGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-registry-link) CHECK_REGISTRY_LINK=1; shift ;;
    --registry) REGISTRY_PATH="$2"; shift 2 ;;
    --check-recommended-consistency) CHECK_RECOMMENDED_CONSISTENCY=1; shift ;;
    --check-history-append-only) CHECK_HISTORY_APPEND_ONLY=1; shift ;;
    --now) VSF_NOW="$2"; shift 2 ;;
    --max-age-days) VSF_MAX_AGE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: validate-source-file.sh <path> [--check-registry-link --registry <path>] [--check-recommended-consistency] [--check-history-append-only]" >&2
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

# §2.21 source folder contract — checks layered ahead of the JSON-schema
# validation pipeline. These are the contract invariants enumerated in
# §2.21: required source-header fields, URL https-only, content_hash
# sha256: format, fetched_at UTC + not-future, source.id kebab-case,
# rule-id uniqueness within file, rule.id string type, freshness
# window (when --now and --max-age-days are passed).
VSF_SOURCE_FILE="$SOURCE_FILE" VSF_NOW="$VSF_NOW" VSF_MAX_AGE="$VSF_MAX_AGE" ruby -ryaml -e '
require "time"
path = ENV["VSF_SOURCE_FILE"]
now_iso = ENV["VSF_NOW"].to_s
max_age = ENV["VSF_MAX_AGE"].to_s
data = YAML.unsafe_load_file(path) rescue nil
src = data.is_a?(Hash) ? data["source"] : nil
errors = []
stale_warning = false

if src.is_a?(Hash)
  # §2.21 supplementary checks (the existing JSON-schema layer already
  # enforces required fields, minLength, types). These extra checks
  # cover behavioral contract details (kebab-case id, https URL,
  # content_hash sha256:<hex>, UTC fetched_at, future-fetched_at,
  # max-age-days freshness) that the schema does not encode.

  # source.id kebab-case format (only fires when id is present AND
  # non-empty AND not kebab — empty/missing is left to the schema).
  if src.key?("id") && src["id"].is_a?(String) && !src["id"].empty? &&
     src["id"] !~ /\A[a-z0-9][a-z0-9-]*\z/
    errors << "invalid source id format=#{src["id"]} expected_format=kebab-case"
  end

  # authoritative_publisher non-empty (only fires when present-but-empty;
  # missing-entirely is left to the JSON-schema layer).
  if src.key?("authoritative_publisher") && src["authoritative_publisher"].to_s.strip.empty?
    errors << "authoritative_publisher must not be empty"
  end

  # URL must be https://.
  if src.key?("authoritative_url") && src["authoritative_url"].is_a?(String) &&
     !src["authoritative_url"].start_with?("https://")
    errors << "authoritative_url must use https://"
  end

  # content_hash must be sha256:<hex>.
  if src.key?("content_hash") && src["content_hash"].is_a?(String) &&
     !(src["content_hash"] =~ /\Asha256:[a-zA-Z0-9]+\z/)
    errors << "invalid content_hash format=#{src["content_hash"]} expected=sha256:<hex>"
  end

  # fetched_at must be UTC ISO-8601 with trailing Z. YAML parses ISO
  # timestamps as Time objects; handle both Time and String forms.
  if src.key?("fetched_at")
    fa_raw = src["fetched_at"]
    fa_str = fa_raw.is_a?(Time) ? fa_raw.iso8601 : fa_raw.to_s
    fa_t = nil
    if fa_raw.is_a?(Time)
      fa_t = fa_raw
      unless fa_raw.utc?
        errors << "invalid fetched_at=#{fa_str}: must be UTC (Z suffix)"
      end
    elsif fa_raw.is_a?(String)
      unless fa_str.end_with?("Z")
        errors << "invalid fetched_at=#{fa_str}: must be UTC with trailing Z"
      end
      begin
        fa_t = Time.iso8601(fa_str)
      rescue
      end
    end
    if !now_iso.empty? && fa_t
      begin
        now_t = Time.iso8601(now_iso)
        if fa_t > now_t
          errors << "fetched_at=#{fa_str} is in the future relative to now=#{now_iso}"
        end
        if !max_age.empty?
          age_days = (now_t - fa_t) / 86400.0
          if age_days > max_age.to_f
            STDERR.write("validate-source-file: stale fetched_at=#{fa_str} age_days=#{age_days.to_i} max_age_days=#{max_age}\n")
            stale_warning = true
          end
        end
      rescue
      end
    end
  end
end

# rules-level checks: id collision and id-must-be-string.
if data.is_a?(Hash) && data["rules"].is_a?(Array)
  seen = {}
  data["rules"].each_with_index do |r, i|
    next unless r.is_a?(Hash) && r.key?("id")
    rid = r["id"]
    unless rid.is_a?(String)
      errors << "rule[#{i}].id is wrong type=#{rid.class.name} (expected string)"
      next
    end
    if seen[rid]
      errors << "duplicate rule id=#{rid} (also at rule[#{seen[rid]}])"
    else
      seen[rid] = i
    end
  end
end

errors.each { |e| STDERR.write("validate-source-file: #{e}\n") }

if !errors.empty?
  exit 2
end
if stale_warning
  exit 1
end
' || { rc=$?; exit "$rc"; }

# O-7: --check-history-append-only verifies rule_state_history is
# consistent with current rule_state (history.last.to must equal
# current rule_state) AND timestamps are monotonically increasing.
if [[ "$CHECK_HISTORY_APPEND_ONLY" -eq 1 ]]; then
  SOURCE_FILE="$SOURCE_FILE" node -e '
    const fs = require("fs");
    const c = fs.readFileSync(process.env.SOURCE_FILE, "utf8");
    let bad = false;
    const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\brule_state:\s*([a-zA-Z_-]+)[\s\S]*?\brule_state_history:\s*\[([^\]]*)\]/g;
    let m;
    while ((m = ruleRe.exec(c)) !== null) {
      const rid = m[1];
      const currentState = m[2];
      const histBody = m[3];
      const tsList = (histBody.match(/timestamp:\s*([0-9T:Z-]+)/g) || []).map(s => s.replace(/timestamp:\s*/, ""));
      for (let i = 1; i < tsList.length; i++) {
        if (new Date(tsList[i]).getTime() < new Date(tsList[i-1]).getTime()) {
          process.stderr.write(`${rid}: rule_state_history non-monotonic timestamps (${tsList[i-1]} > ${tsList[i]})\n`);
          bad = true;
        }
      }
      const toList = (histBody.match(/to:\s*([a-zA-Z_-]+)/g) || []).map(s => s.replace(/to:\s*/, ""));
      if (toList.length > 0 && toList[toList.length - 1] !== currentState) {
        process.stderr.write(`${rid}: rule_state_history non-monotonic - last entry says "to: ${toList[toList.length - 1]}" but current rule_state is "${currentState}"\n`);
        bad = true;
      }
    }
    process.exit(bad ? 2 : 0);
  '
  exit $?
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
    data = YAML.unsafe_load_file(ARGV[0])
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
    reg = begin; YAML.unsafe_load_file(ARGV[0]); rescue; nil; end
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
