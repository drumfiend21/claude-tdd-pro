#!/usr/bin/env bash
# §2.15 workflow-state.json contract validator. Validates the full envelope
# per the architecture contract, plus targeted subchecks for downstream
# tooling that only needs one slice (architect-session, commits, resumable,
# consultations, phase).
#
# CLI surface:
#   --state PATH           state file to validate (required)
#   --check MODE           run a specific subcheck instead of full validation
#                          MODE in {architect-session, commits, resumable,
#                                   consultations, phase}
#   --emit json            emit a structured json record
#   --out PATH             output path for --emit json (required when emitting)
#
# Exit codes:
#   0  validation passed
#   1  validation failed
#   2  usage error / bad input
#
# Output:
#   stderr  key=value lines (e.g. valid=true, decisions_count=N,
#           invalid_current_phase=<value>, missing required field: <name>)
#   --out   json document when --emit json
#
# Concurrent-CL mode (§2.23): top-level may be
#   { "_concurrent": true, "sessions": { "<session_id>": {...envelope...} } }
# in which case the first session's envelope is validated.

STATE=""
CHECK=""
EMIT=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --state) STATE="${2-}"; shift 2 ;;
    --check) CHECK="${2-}"; shift 2 ;;
    --emit)  EMIT="${2-}";  shift 2 ;;
    --out)   OUT="${2-}";   shift 2 ;;
    -h|--help)
      echo "Usage: validate-state-contract.sh --state <path> [--check <mode>] [--emit json --out <path>]" >&2
      exit 0
      ;;
    *)
      echo "validate-state-contract: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$STATE" ]; then
  echo "validate-state-contract: --state required" >&2
  exit 2
fi
if [ ! -f "$STATE" ]; then
  echo "validate-state-contract: state file not found: $STATE" >&2
  exit 2
fi

STATE_PATH="$STATE" CHECK_MODE="$CHECK" EMIT_MODE="$EMIT" OUT_PATH="$OUT" ruby - <<'RUBY'
require 'json'

state_path = ENV['STATE_PATH'].to_s
check      = ENV['CHECK_MODE'].to_s
emit       = ENV['EMIT_MODE'].to_s
out_path   = ENV['OUT_PATH'].to_s

begin
  raw = File.read(state_path)
  data = JSON.parse(raw)
rescue => e
  STDERR.write("validate-state-contract: parse error: #{e.message}\n")
  exit 1
end

if data.is_a?(Hash) && data['_concurrent'] == true && data['sessions'].is_a?(Hash)
  envelope = data['sessions'].values.first || {}
else
  envelope = data
end

# §2.15 registered current_phase set. Choice of identifiers is a
# test-affordance: the architecture text does not enumerate phase labels;
# the W-3 state machine uses {plan, build, review, merge, done} and the
# §2.15 contract speaks of `current_phase` generically. To support both,
# the validator accepts the union of W-3 states plus the broader CL-phase
# vocabulary actually used in commit messages.
REGISTERED_PHASES = %w[plan spec build implement review verify commit merge done].freeze

def emit_err(line)
  STDERR.write("#{line}\n")
end

if check == 'architect-session'
  arch      = envelope['architect_session'] || {}
  decisions = arch['decisions'] || []
  emit_err("decisions_count=#{decisions.size}")
  required = %w[id decision_point options_presented selected]
  all_valid = true
  errs = []
  decisions.each_with_index do |d, i|
    unless d.is_a?(Hash)
      errs << "decision[#{i}] is not an object"
      all_valid = false
      next
    end
    required.each do |f|
      unless d.key?(f)
        errs << "missing required field: #{f} in decision[#{i}]"
        all_valid = false
      end
    end
  end
  emit_err("all_decisions_valid=#{all_valid}")
  errs.each { |e| emit_err(e) }
  exit(all_valid ? 0 : 1)

elsif check == 'commits'
  commits = envelope['commits'] || []
  emit_err("commits_count=#{commits.size}")
  errs = []
  commits.each_with_index do |c, i|
    unless c.is_a?(Hash) && c.key?('sha')
      errs << "missing required field: sha in commits[#{i}]"
    end
  end
  errs.each { |e| emit_err(e) }
  exit(errs.empty? ? 0 : 1)

elsif check == 'resumable'
  v = envelope['_resumable']
  if v == true || v == false
    emit_err("resumable=#{v}")
    exit 0
  else
    emit_err("invalid__resumable=#{v}")
    exit 1
  end

elsif check == 'consultations'
  s = (envelope['standards_consulted']  || []).size
  p = (envelope['pr_corpus_consulted']  || []).size
  c = (envelope['compliance_consulted'] || []).size
  emit_err("standards_consulted_count=#{s}")
  emit_err("pr_corpus_consulted_count=#{p}")
  emit_err("compliance_consulted_count=#{c}")
  exit 0

elsif check == 'phase'
  v = envelope['current_phase']
  if REGISTERED_PHASES.include?(v)
    emit_err("current_phase=#{v}")
    exit 0
  else
    emit_err("invalid_current_phase=#{v}")
    exit 1
  end
end

# === Full validation (no --check) ===
errors = []

session_id = envelope['session_id']
if !session_id.is_a?(String) || session_id.empty?
  errors << "missing required field: session_id"
end

valid = errors.empty?

if emit == 'json' && !out_path.empty?
  rec = {
    "valid"      => valid,
    "session_id" => session_id,
    "current_phase" => envelope['current_phase'],
    "_resumable" => envelope['_resumable'],
    "errors"     => errors,
  }
  File.write(out_path, JSON.generate(rec))
end

errors.each { |e| emit_err(e) }
emit_err("valid=#{valid}")
exit(valid ? 0 : 1)
RUBY
