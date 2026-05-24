#!/usr/bin/env bash
# §2.3 Subagent contract validator. Validates an agent file's YAML
# frontmatter for the §2.3 required-fields envelope: name, model,
# prompt_id, prompt_version. Validates the prompt_migration_status enum:
# original | migrated-zero-delta | migrated-with-delta:<reason>.
#
# Usage:
#   bash validate-contract.sh --agent <path-to-agent.md>
#
# Exit codes:
#   0  valid
#   1  invalid
#   2  usage error

AGENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: validate-contract.sh --agent <path>" >&2; exit 0 ;;
    *) echo "validate-contract: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$AGENT" ]; then
  echo "validate-contract: --agent required" >&2
  exit 2
fi
if [ ! -f "$AGENT" ]; then
  echo "validate-contract: file not found: $AGENT" >&2
  exit 2
fi

AGENT_PATH="$AGENT" ruby - <<'RUBY'
require 'yaml'

agent_path = ENV['AGENT_PATH'].to_s
content = File.read(agent_path)

# Extract YAML frontmatter between leading --- and the next --- line.
fm_match = content.match(/\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m)
unless fm_match
  STDERR.write("validate-contract: missing YAML frontmatter\n")
  exit 1
end

begin
  fm = YAML.unsafe_load(fm_match[1])
rescue => e
  STDERR.write("validate-contract: frontmatter parse error: #{e.message}\n")
  exit 1
end

unless fm.is_a?(Hash)
  STDERR.write("validate-contract: frontmatter is not a mapping\n")
  exit 1
end

errors = []

%w[name model prompt_id prompt_version].each do |f|
  unless fm.key?(f) && !fm[f].to_s.strip.empty?
    errors << "missing required field: #{f}"
  end
end

VALID_STATUS_PREFIX = %w[original migrated-zero-delta].freeze

if fm.key?('prompt_migration_status')
  v = fm['prompt_migration_status'].to_s
  if VALID_STATUS_PREFIX.include?(v)
    STDERR.write("prompt_migration_status=#{v}\n")
  elsif v.start_with?('migrated-with-delta:')
    reason = v.sub(/^migrated-with-delta:/, '')
    if reason.strip.empty?
      errors << "invalid_prompt_migration_status=#{v} (delta reason missing)"
    else
      STDERR.write("prompt_migration_status=migrated-with-delta\n")
      STDERR.write("delta_reason=#{reason}\n")
    end
  else
    errors << "invalid_prompt_migration_status=#{v}"
    errors << "allowed=original|migrated-zero-delta|migrated-with-delta:<reason>"
  end
end

if errors.empty?
  STDERR.write("valid=true\n")
  exit 0
else
  errors.each { |e| STDERR.write("#{e}\n") }
  exit 1
end
RUBY
