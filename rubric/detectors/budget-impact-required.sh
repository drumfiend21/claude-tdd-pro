#!/usr/bin/env bash
# rubric/detectors/budget-impact-required.sh — O-0 enforcement detector.
# Per §13 O-0: "no new components without budget impact estimate."
#
# Walks skills/, agents/, hooks/scripts/ under $PWD (or --root) and verifies
# every component file declares a budget_impact_estimate block with the
# required shape:
#   budget_impact_estimate:
#     tokens_per_invocation: <number>
#     expected_invocations_per_day: <number>
#     monetary_estimate_usd: <number>
#
# Optionally takes --file <path> to check a single component.
#
# Exit codes per §2.2 detector contract:
#   0 — every component has a valid budget_impact_estimate block
#   2 — at least one component is missing or invalid

set -uo pipefail

ROOT="$PWD"
SINGLE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --file) SINGLE_FILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: budget-impact-required.sh [--root <dir>] [--file <component>]" >&2; exit 0 ;;
    *) echo "budget-impact-required: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Collect candidate files: SKILL.md under skills/, *.md under agents/,
# *.sh under hooks/scripts/.
FILES=()
if [[ -n "$SINGLE_FILE" ]]; then
  FILES+=("$SINGLE_FILE")
else
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    FILES+=("$f")
  done < <(
    find "$ROOT/skills" -name "SKILL.md" -type f 2>/dev/null
    find "$ROOT/agents" -name "*.md" -type f 2>/dev/null
    find "$ROOT/hooks/scripts" -name "*.sh" -type f 2>/dev/null
  )
fi

[[ ${#FILES[@]} -eq 0 ]] && { echo "budget-impact-required: no component files under $ROOT" >&2; exit 0; }

ANY_FAIL=0
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  CONTENT=$(cat "$f")

  # Look for budget_impact_estimate block. The block is required.
  if ! echo "$CONTENT" | grep -q "^budget_impact_estimate:"; then
    echo "$(basename "$f"):1: budget_impact_estimate is required (per O-0); missing in $f" >&2
    ANY_FAIL=1
    continue
  fi

  # Parse the block via Ruby/YAML for validation.
  VALIDATION=$(echo "$CONTENT" | ruby -ryaml -e '
    src = STDIN.read
    # Strip leading shebang if present
    src = src.lines.drop_while { |l| l.start_with?("#!") || l.strip == "" }.join
    begin
      doc = YAML.safe_load(src, permitted_classes: [Symbol], aliases: false)
    rescue => e
      STDERR.puts "yaml parse error: #{e.message}"
      exit 2
    end
    bie = doc.is_a?(Hash) ? doc["budget_impact_estimate"] : nil
    if !bie.is_a?(Hash)
      STDERR.puts "budget_impact_estimate must be a YAML map"
      exit 2
    end
    %w[tokens_per_invocation expected_invocations_per_day monetary_estimate_usd].each do |k|
      v = bie[k]
      unless v.is_a?(Numeric)
        STDERR.puts "budget_impact_estimate.#{k}: required, must be a number (got: #{v.inspect})"
        exit 2
      end
    end
    exit 0
  ' 2>&1) || { echo "$(basename "$f"):1: $VALIDATION" >&2; ANY_FAIL=1; continue; }
done

[[ "$ANY_FAIL" -eq 1 ]] && exit 2
exit 0
