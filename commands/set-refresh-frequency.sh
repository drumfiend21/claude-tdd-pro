#!/usr/bin/env bash
# commands/set-refresh-frequency.sh - set the global standards-refresh cadence chosen at
# install time, into the S-22 operator registry .claude-tdd-pro/FETCH-FREQUENCIES.yaml
# (v1.18 §28.23). Accepts a <N><unit> value where unit is m(inutes) / h(ours) / d(ays) /
# w(eeks) / mo(nths) — extending the §2.28 cadence grammar additively with d/w/mo —
# or a bare calendar token. Default: 1d (every day). Common singulars are canonicalized
# to the existing calendar tokens (1d->daily, 1w->weekly, 1mo->monthly) so the existing
# in-use poll scheduler (S-20) resolves them unchanged.
#
# CLI: <frequency>  [--config <path>]   exit 0 ok / 2 invalid.
# stderr: `refresh-frequency set=<input> default_global=<normalized>`

set -uo pipefail
FREQ=""; CONFIG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: set-refresh-frequency.sh <N><m|h|d|w|mo> | <daily|weekly|monthly|quarterly|on-demand> [--config <path>]" >&2; exit 0 ;;
    -*) echo "set-refresh-frequency: unknown arg: $1" >&2; exit 2 ;;
    *) FREQ="$1"; shift ;;
  esac
done
[ -z "$FREQ" ] && FREQ="1d"   # default: every day
[ -z "$CONFIG" ] && CONFIG="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}/.claude-tdd-pro/FETCH-FREQUENCIES.yaml"

# validate the cadence grammar (§2.28 + the §28.23 d/w/mo extension)
case "$FREQ" in
  daily|weekly|monthly|quarterly|on-demand) NORM="$FREQ" ;;
  *)
    if printf '%s' "$FREQ" | grep -qE '^[0-9]+(ms|s|m|h|d|w|mo)$'; then
      case "$FREQ" in
        1d)  NORM="daily" ;;
        1w)  NORM="weekly" ;;
        1mo) NORM="monthly" ;;
        *)   NORM="$FREQ" ;;
      esac
    else
      echo "set-refresh-frequency: invalid frequency '$FREQ' (use <N><m|h|d|w|mo> or daily|weekly|monthly|quarterly|on-demand)" >&2
      exit 2
    fi
    ;;
esac

mkdir -p "$(dirname "$CONFIG")" 2>/dev/null || true
cat > "$CONFIG" <<YAML
# S-22 operator cadence registry (.claude-tdd-pro/FETCH-FREQUENCIES.yaml) — §2.28 / §28.23.
# Global default standards-refresh cadence, chosen at install time. Per-source overrides
# may be added under \`overrides:\`. Grammar: <N><m|h|d|w|mo> or daily|weekly|monthly|
# quarterly|on-demand. Sub-day cadences fire only while a Claude Code session is active.
default: $NORM
chosen_at_install: "$FREQ"
overrides: {}
YAML

echo "refresh-frequency set=$FREQ default_global=$NORM" >&2
exit 0
