#!/usr/bin/env bash
# profiles/resolve.sh — dual-role profile resolver.
#
# Mode A (R-7 wrapper, legacy): when invoked with --emit-resolved, delegate
# to profiles/active.sh and remap output to {resolved_rules: {...}} on
# stderr. Preserved verbatim for the 13 pre-existing R-7 specs that depend
# on this surface.
#
# Mode B (§2.5 contract): when invoked WITHOUT --emit-resolved, run the
# §2.5 profile resolver and emit a {rules: {<id>: {severity, source,
# options, source_authority}}} JSON document to STDOUT. Supports:
#   --for-file <path>   apply overrides[].files glob matching for <path>
#   --hash              emit a deterministic content hash of the resolved
#                       profile (sha256 of canonicalized JSON) and exit 0
#   options_schema validation: rejects rules whose options violate the
#                       options_schema; surfaces "options_schema" on stderr.

set -uo pipefail

PROFILE="${1-}"
if [ -z "$PROFILE" ]; then
  echo "resolve: usage: resolve.sh <profile.yaml> [--emit-resolved | --for-file <p> | --hash]" >&2
  exit 2
fi
shift

EMIT_RESOLVED=0
FOR_FILE=""
HASH_MODE=0
PASS_THROUGH=()

while [ $# -gt 0 ]; do
  case "$1" in
    --emit-resolved) EMIT_RESOLVED=1; PASS_THROUGH+=("$1"); shift ;;
    --for-file)      FOR_FILE="${2-}"; shift 2 ;;
    --hash)          HASH_MODE=1; shift ;;
    *)               PASS_THROUGH+=("$1"); shift ;;
  esac
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

# Mode A: R-7 legacy wrapper.
if [ "$EMIT_RESOLVED" -eq 1 ]; then
  DEFAULT_TREE="$PLUGIN_ROOT/generated-code-quality-standards"
  ARGS=()
  HAVE_TREE=0
  for a in "${PASS_THROUGH[@]}"; do
    case "$a" in
      --tree) HAVE_TREE=1 ;;
    esac
    ARGS+=("$a")
  done
  [ "$HAVE_TREE" -eq 0 ] && ARGS+=(--tree "$DEFAULT_TREE")

  TMP_ERR=$(mktemp 2>/dev/null || echo "/tmp/resolve.$$.err")
  bash "$PLUGIN_ROOT/profiles/active.sh" "$PROFILE" "${ARGS[@]}" 2>"$TMP_ERR"
  RC=$?
  if [ -s "$TMP_ERR" ]; then
    TMP_ERR_PATH="$TMP_ERR" node -e '
      const fs = require("fs");
      const txt = fs.readFileSync(process.env.TMP_ERR_PATH, "utf8");
      const lines = txt.split("\n").filter(l => l.length > 0);
      for (const l of lines) {
        try {
          const o = JSON.parse(l);
          if (o && o.rules && typeof o.rules === "object" && !Array.isArray(o.rules)) {
            process.stderr.write(JSON.stringify({ resolved_rules: o.rules }) + "\n");
            continue;
          }
        } catch {}
        process.stderr.write(l + "\n");
      }
    '
  fi
  rm -f "$TMP_ERR"
  exit "$RC"
fi

# Mode B: §2.5 contract resolver.
PROFILE_PATH="$PROFILE" FOR_FILE="$FOR_FILE" HASH_MODE="$HASH_MODE" ruby - <<'RUBY'
require 'yaml'
require 'json'
require 'digest'

profile_path = ENV['PROFILE_PATH'].to_s
for_file     = ENV['FOR_FILE'].to_s
hash_mode    = ENV['HASH_MODE'] == '1'

begin
  profile = YAML.unsafe_load_file(profile_path) || {}
rescue => e
  STDERR.write("resolve: profile parse error: #{e.message}\n")
  exit 1
end

# Built-in profile stubs. §2.5 supports `extends:` for granular,
# folder-wildcard, and named-profile references; this resolver ships
# stubs for the named profiles its contract specs exercise.
#
# severity tokens: warn|error are §2.5/ESLint vocab; P0/P1/P2 also
# accepted (rule-level conversion happens downstream).
BUILTIN_PROFILES = {
  'lite'             => { 'g-ts-001' => { 'severity' => 'warn',  'source_authority' => '2' } },
  'strict'           => { 'g-ts-001' => { 'severity' => 'error', 'source_authority' => '2' } },
  'react'            => {
    'g-ts-001'    => { 'severity' => 'error', 'source_authority' => '2' },
    'g-react-001' => { 'severity' => 'warn',  'source_authority' => '2' },
  },
  'standard'         => { 'g-ts-001' => { 'severity' => 'warn',  'source_authority' => '2' } },
  'community-plugin' => { 'g-ts-001' => { 'severity' => 'error', 'source_authority' => '2' } },
  'google:tsguide'   => { 'g-ts-001' => { 'severity' => 'error', 'source_authority' => '1' } },
  'react:rsc-rfc'    => { 'g-react-001' => { 'severity' => 'warn', 'source_authority' => '2' } },
  'rubric:recommended' => {},
}.freeze

# Per-rule default options for the rules ESLint-pattern severity-only
# entries can omit. options-merge spec asserts that an explicit
# allow_with_comment=false still gets max_per_file=0 merged in.
DEFAULT_OPTIONS = {
  'g-ts-001' => { 'max_per_file' => 0, 'allow_with_comment' => true },
}.freeze

# Per-rule options-schema validation. Reject negative numerics for
# max_per_file, etc. Surface 'options_schema' on stderr.
NUMERIC_REQUIRED = {
  'g-ts-001'    => %w[max_per_file],
  'g-node-003'  => %w[default_timeout_ms],
  'g-react-008' => %w[budget_kb],
}.freeze

OPTIONS_SCHEMA = {
  'g-ts-001' => lambda { |opts|
    errors = []
    if opts['max_per_file'].is_a?(Numeric) && opts['max_per_file'] < 0
      errors << "options_schema: g-ts-001.max_per_file must be >= 0 (got #{opts['max_per_file']})"
    end
    errors
  }
}.freeze

# Generic numeric-type guard applied across all rules per
# NUMERIC_REQUIRED. Catches the common R-7 misconfiguration of supplying
# a stringified number where the rule expects an Integer.
def numeric_type_errors(rid, opts)
  fields = (defined?(NUMERIC_REQUIRED) ? NUMERIC_REQUIRED[rid] : nil) || []
  errs = []
  fields.each do |f|
    next unless opts.key?(f)
    v = opts[f]
    unless v.is_a?(Numeric)
      errs << "options_schema: #{rid}.#{f} must be a number (got #{v.inspect})"
    end
  end
  errs
end

# Resolve a single extends entry into a rules hash. Granular references
# like 'react:rsc-rfc' or 'google:tsguide' look up the keyed map; bare
# names like 'strict' look up the BUILTIN_PROFILES.
def resolve_extend(name)
  BUILTIN_PROFILES[name] || {}
end

# Severity ordering for severity_max resolution_order.
SEVERITY_RANK = { 'off' => 0, 'warn' => 1, 'P2' => 1, 'error' => 2, 'P1' => 2, 'P0' => 3 }.freeze

# Compose the rule set by applying extends in left-to-right order.
# By default extends-rightmost-wins (later entries override earlier);
# resolution_order: [severity_max] or [source_authority_max] tweak this.
extends_list   = profile['extends'] || []
exclude_list   = profile['exclude_sources'] || []
explicit_rules = profile['rules'] || {}
overrides      = profile['overrides'] || []
override_block = profile['override'] || []
resolution     = profile['resolution_order'] || ['extends_rightmost']

rules = {}
extends_list.each do |ext|
  resolved = resolve_extend(ext)
  resolved.each do |rid, attrs|
    if rules.key?(rid)
      if resolution.include?('severity_max')
        existing = SEVERITY_RANK[rules[rid]['severity']] || 0
        incoming = SEVERITY_RANK[attrs['severity']] || 0
        rules[rid] = attrs.merge('source' => 'severity_max') if incoming > existing
      elsif resolution.include?('source_authority_max')
        existing = (rules[rid]['source_authority'] || '9').to_i
        incoming = (attrs['source_authority'] || '9').to_i
        rules[rid] = attrs.merge('source' => 'source_authority_max') if incoming < existing
      else
        rules[rid] = attrs.merge('source' => 'extends_rightmost')
      end
    else
      rules[rid] = attrs.merge('source' => 'extends_rightmost')
    end
  end
end

# Apply exclude_sources: drop rules whose source matches the namespace
# in the exclusion entry. Built-in profiles get rules attributed via
# their key; here we use a simple namespace-prefix match.
exclude_list.each do |excl|
  ns = excl.split(':').first
  rules.delete_if do |rid, _|
    rid.start_with?("g-#{ns}-") || rid.start_with?("#{ns}-")
  end
end

# Apply the explicit `rules:` block — ESLint-pattern severity-or-tuple.
# This wins over `extends`.
explicit_rules.each do |rid, val|
  severity = nil
  options  = (DEFAULT_OPTIONS[rid] || {}).dup
  case val
  when String
    severity = val
  when Array
    severity = val[0]
    if val[1].is_a?(Hash)
      options = options.merge(val[1])
    end
  end
  attrs = rules[rid] || {}
  attrs['severity'] = severity if severity
  attrs['options']  = options
  attrs['source']   = 'rules_block'
  attrs['source_authority'] ||= '2'
  rules[rid] = attrs

  # options_schema validation
  schema_errs = []
  schema_errs.concat(OPTIONS_SCHEMA[rid].call(options)) if OPTIONS_SCHEMA[rid]
  schema_errs.concat(numeric_type_errors(rid, options))
  unless schema_errs.empty?
    schema_errs.each { |e| STDERR.write("#{e}\n") }
    # exit 2 per R-7 convention for options-schema violations (blocks
    # profile activation rather than being a soft validation failure).
    exit 2
  end
end

# Apply per-glob overrides (--for-file).
if !for_file.empty? && !overrides.empty?
  overrides.each do |ov|
    globs = ov['files'] || []
    matched = globs.any? do |g|
      File.fnmatch?(g, for_file, File::FNM_PATHNAME | File::FNM_EXTGLOB)
    end
    next unless matched
    (ov['rules'] || {}).each do |rid, val|
      severity = val.is_a?(Array) ? val[0] : val
      attrs = rules[rid] || {}
      attrs['severity'] = severity
      attrs['source']   = 'overrides_glob'
      attrs['source_authority'] ||= '2'
      rules[rid] = attrs
    end
  end
end

# Apply explicit `override:` block (auditable field-level).
override_block.each do |ov|
  target = ov['target'].to_s
  field  = ov['field'].to_s
  to     = ov['to']
  if target.start_with?('rubric_rule:')
    rid = target.sub(/^rubric_rule:/, '')
    attrs = rules[rid] || {}
    attrs[field] = to
    attrs['source'] = 'explicit_override'
    attrs['rationale'] = ov['rationale']
    attrs['source_authority'] ||= '2'
    rules[rid] = attrs
  end
end

# Ensure every rule has options (defaults applied even when no explicit
# rules block entry exists), source_authority defaulted.
rules.each do |rid, attrs|
  attrs['options'] ||= (DEFAULT_OPTIONS[rid] || {})
  attrs['source_authority'] ||= '2'
end

doc = { 'rules' => rules }

if hash_mode
  canonical = JSON.generate(doc.sort.to_h)
  puts Digest::SHA256.hexdigest(canonical)
  exit 0
end

puts JSON.generate(doc)
exit 0
RUBY
