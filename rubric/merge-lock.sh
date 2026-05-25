#!/usr/bin/env bash
# §2.7 Lock file merger. Combines two lock.json documents per §2.7
# merge semantics: standards_versions / pr_corpus_patterns / compliance_*
# merge by union; rubric / detectors / workflow_state_hash / prompt_registry_hash
# last-writer-wins with conflict surfaced on stderr.
#
# CLI:
#   --a PATH       first lock file (older / left side)
#   --b PATH       second lock file (newer / right side — wins on conflict)
#   --out PATH     merged output path
#   --emit conflicts   emit per-key conflict lines to stderr (e.g.
#                      conflict=rubric.hash a=abc b=xyz)
#
# Exit codes:
#   0  merged
#   2  usage error

A=""
B=""
OUT=""
EMIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --a)    A="${2-}";    shift 2 ;;
    --b)    B="${2-}";    shift 2 ;;
    --out)  OUT="${2-}";  shift 2 ;;
    --emit) EMIT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: merge-lock.sh --a <path> --b <path> --out <path> [--emit conflicts]" >&2; exit 0 ;;
    *) echo "merge-lock: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$A" ] || [ -z "$B" ] || [ -z "$OUT" ]; then
  echo "merge-lock: --a, --b, --out all required" >&2
  exit 2
fi
if [ ! -f "$A" ] || [ ! -f "$B" ]; then
  echo "merge-lock: input file missing" >&2
  exit 2
fi

A_PATH="$A" B_PATH="$B" OUT_PATH="$OUT" EMIT_MODE="$EMIT" ruby - <<'RUBY'
require 'json'

a = JSON.parse(File.read(ENV['A_PATH']))
b = JSON.parse(File.read(ENV['B_PATH']))
emit_conflicts = ENV['EMIT_MODE'].to_s == 'conflicts'

UNION_KEYS = %w[
  standards_versions pr_corpus_patterns compliance_versions
  model_pins
].freeze

LAST_WIN_OBJ_KEYS = %w[rubric detectors prompts].freeze

LAST_WIN_SCALAR_KEYS = %w[
  workflow_state_hash prompt_registry_hash profile_snapshot_hash
  quality_standards_directory_hash plugin_version rubric_semver
].freeze

def conflict(emit_conflicts, key_path, av, bv)
  return unless emit_conflicts
  STDERR.write("conflict=#{key_path} a=#{av} b=#{bv}\n")
end

merged = {}

# Pass 1: keys present in either A or B (preserve original ordering of A's keys
# then any B-only keys).
seen = {}
(a.keys + b.keys).each do |k|
  next if seen[k]
  seen[k] = true

  if UNION_KEYS.include?(k)
    av = a[k] || {}
    bv = b[k] || {}
    if av.is_a?(Hash) && bv.is_a?(Hash)
      merged[k] = av.merge(bv) # B wins on overlapping keys; union otherwise.
    else
      merged[k] = bv.nil? ? av : bv
    end
  elsif LAST_WIN_OBJ_KEYS.include?(k)
    av = a[k]
    bv = b[k]
    if av && bv && av != bv
      av.each do |subk, subv|
        if bv.key?(subk) && bv[subk] != subv
          conflict(emit_conflicts, "#{k}.#{subk}", subv, bv[subk])
        end
      end
    end
    merged[k] = bv.nil? ? av : bv
  elsif LAST_WIN_SCALAR_KEYS.include?(k)
    av = a[k]
    bv = b[k]
    if !av.nil? && !bv.nil? && av != bv
      conflict(emit_conflicts, k, av, bv)
    end
    merged[k] = bv.nil? ? av : bv
  else
    # default: B wins if present
    merged[k] = b.key?(k) ? b[k] : a[k]
  end
end

File.write(ENV['OUT_PATH'], JSON.generate(merged))
STDERR.write("merge-lock: wrote #{ENV['OUT_PATH']}\n")
RUBY
