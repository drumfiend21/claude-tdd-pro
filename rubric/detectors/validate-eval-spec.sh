#!/usr/bin/env bash
# §2.4 Eval spec schema contract validator. Validates a single eval spec
# JSON file (the format consumed by evals/runner.sh) against the §2.4
# contract: required {name, command, expect}; enums + types validated on
# optional fields {category, rationale, subject, subject_target_hash,
# bootstrap_seed, stale_when_target_changes}.
#
# Usage:
#   bash validate-eval-spec.sh <path-to-spec.json>
#
# Exit codes:
#   0  valid
#   1  invalid (errors written to stderr; each line mentions the
#      offending field name so grep-based assertions can locate it)
#   2  usage error / bad input

if [ $# -ne 1 ]; then
  echo "validate-eval-spec: usage: validate-eval-spec.sh <path-to-spec.json>" >&2
  exit 2
fi

SPEC="$1"
if [ ! -f "$SPEC" ]; then
  echo "validate-eval-spec: file not found: $SPEC" >&2
  exit 2
fi

SPEC_PATH="$SPEC" ruby - <<'RUBY'
require 'json'

spec_path = ENV['SPEC_PATH'].to_s

begin
  spec = JSON.parse(File.read(spec_path))
rescue => e
  STDERR.write("validate-eval-spec: parse error: #{e.message}\n")
  exit 1
end

errors = []

# Required top-level fields (consumed by evals/runner.sh).
%w[name command expect].each do |f|
  unless spec.key?(f)
    errors << "missing required field: #{f}"
  end
end

# §2.4 category enum.
VALID_CATEGORY = %w[
  react node types foundation standards compliance prompt space
  hardening security tdd operational execution pr-corpus workflow
  rule-engine source-folder
].freeze

if spec.key?('category') && !VALID_CATEGORY.include?(spec['category'])
  errors << "invalid category=#{spec['category']} (allowed: #{VALID_CATEGORY.join('|')})"
end

# rationale: non-empty string if present.
if spec.key?('rationale')
  v = spec['rationale']
  unless v.is_a?(String) && !v.strip.empty?
    errors << "invalid rationale: must be non-empty string (got #{v.inspect})"
  end
end

# subject: format is "<category>:<subject_id>" — loose pattern for the
# contract validator; the strict format lives in the runner.
if spec.key?('subject')
  v = spec['subject']
  unless v.is_a?(String) && v =~ %r{\A[a-z][a-z0-9-]*:[a-z0-9][a-z0-9._/-]*\z}
    errors << "invalid subject=#{v} (expected <category>:<subject_id>)"
  end
end

# subject_target_hash: sha256:<64-hex>.
if spec.key?('subject_target_hash')
  v = spec['subject_target_hash']
  unless v.is_a?(String) && v =~ /\Asha256:[a-f0-9]{64}\z/
    errors << "invalid subject_target_hash=#{v} (expected sha256:<64-hex>)"
  end
end

# bootstrap_seed: strict boolean.
if spec.key?('bootstrap_seed')
  v = spec['bootstrap_seed']
  unless v == true || v == false
    errors << "invalid bootstrap_seed=#{v} (must be true or false)"
  end
end

# stale_when_target_changes: strict boolean.
if spec.key?('stale_when_target_changes')
  v = spec['stale_when_target_changes']
  unless v == true || v == false
    errors << "invalid stale_when_target_changes=#{v} (must be true or false)"
  end
end

if errors.empty?
  STDERR.write("validate-eval-spec: valid=true\n")
  exit 0
else
  errors.each { |e| STDERR.write("validate-eval-spec: #{e}\n") }
  exit 1
end
RUBY
