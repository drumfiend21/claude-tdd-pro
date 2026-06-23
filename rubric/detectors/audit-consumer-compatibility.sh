#!/usr/bin/env bash
# rubric/detectors/audit-consumer-compatibility.sh — the Consumer Compatibility Contract gate
# (§28.40). Enforces the CTP-side invariant "schema-additive with epoch + default" so that a
# pin bump is never breaking on a consumer's enforcement-STATE layer (not only its CLI-signature
# layer). A schema addition is consumer-safe ONLY when consumers can (a) gate floors by the rule's
# introduction epoch and (b) read a defined answer for every absent field.
#
# Checks (/doctor + CI):
#   1. EPOCH: every coding rule carries an `introduced_in` epoch tag. Without it a consumer cannot
#      grandfather legacy tickets/content, and an additive rule retroactively reds old state.
#   2. ABSENT-DEFAULT COVERAGE: every enforcement-relevant OPTIONAL rule field present in the
#      schema is registered in schemas/field-semantics.json with an `absent_default`. A new field
#      that participates in a consumer's floor derivation but has no declared absent-default is a
#      breaking change disguised as additive.
#   3. CONTRACT PRESENT: docs/consumer-compatibility-contract.md exists (the policy + the
#      `consumer_compatibility:` block template every rule-schema-touching ADR must fill).
#
# CLI: [--root <dir>] [--quiet]
# stderr: per violation `consumer-compat surface=<s> item=<x> reason=<...>`; summary
#         `consumer-compat status=<green|red> rules=<n> untagged=<u> undeclared_fields=<f>`
# Exit: 0 contract-honored | 1 violations | 2 usage.

set -uo pipefail
ROOT=""; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: audit-consumer-compatibility.sh [--root <dir>] [--quiet]" >&2; exit 0 ;;
    *) echo "audit-consumer-compatibility: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
command -v ruby >/dev/null 2>&1 || { echo "consumer-compat: ruby required" >&2; exit 2; }

ROOT="$ROOT" QUIET="$QUIET" ruby -ryaml -rjson -e '
  root = ENV["ROOT"]; quiet = ENV["QUIET"] == "1"
  v = 0

  # The optional rule fields that participate in a consumer enforcement derivation. Any of these
  # present in the schema MUST be registered with an absent_default in field-semantics.json.
  ENFORCEMENT_FIELDS = %w[introduced_in applies_to enforced_by applies_to_prose applies_to_prose_kinds]

  # 1. EPOCH: every rule carries introduced_in.
  rules = 0; untagged = 0
  Dir[File.join(root, "generated-code-quality-standards", "*", "*.yaml")].sort.each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    (d["rules"] || []).each do |r|
      next unless r.is_a?(Hash) && r["id"]
      rules += 1
      if r["introduced_in"].to_s.empty?
        untagged += 1; v += 1
        STDERR.puts "consumer-compat surface=epoch item=#{r["id"]} reason=missing-introduced_in" unless quiet
      end
    end
  end

  # 2. ABSENT-DEFAULT COVERAGE: each enforcement field in the schema is registered in field-semantics.
  schema = (JSON.parse(File.read(File.join(root, "schemas/rubric-rule.schema.json"))) rescue {})
  sem = (JSON.parse(File.read(File.join(root, "schemas/field-semantics.json"))) rescue {})
  declared = (sem["fields"] || {})
  schema_props = (schema["properties"] || {}).keys
  undeclared = 0
  ENFORCEMENT_FIELDS.each do |fld|
    next unless schema_props.include?(fld)         # only fields actually in the schema
    unless declared.key?(fld) && declared[fld].key?("absent_default")
      undeclared += 1; v += 1
      STDERR.puts "consumer-compat surface=absent-default item=#{fld} reason=no-declared-absent_default" unless quiet
    end
  end

  # 3. CONTRACT PRESENT.
  unless File.exist?(File.join(root, "docs/consumer-compatibility-contract.md"))
    v += 1
    STDERR.puts "consumer-compat surface=contract item=docs/consumer-compatibility-contract.md reason=missing" unless quiet
  end

  status = v.zero? ? "green" : "red"
  STDERR.puts "consumer-compat status=#{status} rules=#{rules} untagged=#{untagged} undeclared_fields=#{undeclared}" unless quiet
  exit(v.zero? ? 0 : 1)
'
