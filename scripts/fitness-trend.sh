#!/usr/bin/env bash
# Temporal fitness function: weekly trend of the four atomic fitness
# functions plus suite stats. Per docs/FITNESS_FUNCTIONS.md, this is
# the "holistic / temporal" entry in the 2×2 taxonomy.
#
# Intended to run on a weekly cron (e.g., GitHub Actions schedule)
# and append a row to docs/fitness-trend.md. Manual runs supported
# via:
#
#   bash scripts/fitness-trend.sh [--out <path>] [--dry-run]
#
# When the trend shows a non-trivial regression (spec depth
# decreasing >5% week-over-week, suite latency growing >20% over 4
# weeks), opens a GitHub issue tagged "fitness-regression" via the
# gh CLI when available.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
OUT="$PLUGIN_ROOT/docs/fitness-trend.md"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: fitness-trend.sh [--out <path>] [--dry-run]" >&2
      exit 0 ;;
    *) echo "fitness-trend: unknown arg: $1" >&2; exit 2 ;;
  esac
done

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
commit=$(cd "$PLUGIN_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo unknown)

# Run each atomic fitness function and capture the headline line.
sub=$(bash "$PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh" 2>&1 \
  | grep -E "substrate_audit=" | head -1)
cli=$(bash "$PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh" 2>&1 \
  | grep -E "cli_surface_audit=" | head -1)
dep=$(bash "$PLUGIN_ROOT/rubric/detectors/audit-spec-depth.sh" 2>&1 \
  | grep -E "spec_depth_audit=" | head -1)

# Suite stats (warm cache; fast)
suite_start=$SECONDS
suite=$(bash "$PLUGIN_ROOT/evals/runner.sh" --stats 2>&1 | grep -E "^Results:|^    STATS:" | head -2)
suite_elapsed=$(( SECONDS - suite_start ))

row="| $ts | $commit | ${sub:-N/A} | ${cli:-N/A} | ${dep:-N/A} | ${suite_elapsed}s | ${suite//$'\n'/ } |"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "fitness-trend: dry-run; would append:" >&2
  echo "$row" >&2
  exit 0
fi

if [[ ! -f "$OUT" ]]; then
  cat > "$OUT" <<EOF
# Fitness trend

Per docs/FITNESS_FUNCTIONS.md, this is the holistic/temporal entry
in the four-function suite. Written weekly by
\`scripts/fitness-trend.sh\` (also runnable manually).

| Timestamp | Commit | Substrate completeness | CLI surface fidelity | Spec depth | Suite wall | Suite stats |
|---|---|---|---|---|---|---|
EOF
fi

echo "$row" >> "$OUT"
echo "fitness-trend: appended row to $OUT" >&2
