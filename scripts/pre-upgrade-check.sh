#!/usr/bin/env bash
# Pre-upgrade snapshot. Captures the current state before any
# Claude Code update so post-upgrade-verify can diff against it.
#
# Usage:
#   scripts/pre-upgrade-check.sh [--out <path>]
#
# Outputs:
#   - audit/pre-upgrade-<timestamp>.json (default)
#   - telemetry event pre-upgrade.snapshot

set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ts=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$PLUGIN_ROOT/audit/pre-upgrade-${ts}.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: pre-upgrade-check.sh [--out <path>]" >&2; exit 0 ;;
    *) echo "pre-upgrade-check: unknown arg: $1" >&2; exit 2 ;;
  esac
done

claude_version=$(bash "$PLUGIN_ROOT/commands/claude-version-detect.sh" --quiet 2>/dev/null \
  && bash "$PLUGIN_ROOT/commands/claude-version-detect.sh" 2>/dev/null || echo "unknown")
plugin_version=$(node -e 'process.stdout.write(require("'"$PLUGIN_ROOT"'/package.json").version)' 2>/dev/null || echo "unknown")
suite_status="unknown"
if bash "$PLUGIN_ROOT/evals/runner.sh" --filter "cl414-Q-1" >/dev/null 2>&1; then
  suite_status="pass"
else
  suite_status="fail"
fi
standalone_status="unknown"
if bash "$PLUGIN_ROOT/scripts/standalone-verify.sh" --quiet >/dev/null 2>&1; then
  standalone_status="pass"
else
  standalone_status="fail"
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
{
  "snapshot_ts": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "claude_version": "$claude_version",
  "plugin_version": "$plugin_version",
  "suite_smoke": "$suite_status",
  "standalone_verify": "$standalone_status",
  "fitness_gates": {
    "substrate_completeness": "$(bash $PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh --quiet >/dev/null 2>&1 && echo clean || echo dirty)",
    "cli_surface_fidelity":   "$(bash $PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh --quiet >/dev/null 2>&1 && echo clean || echo dirty)",
    "spec_depth":              "$(bash $PLUGIN_ROOT/rubric/detectors/audit-spec-depth.sh --quiet >/dev/null 2>&1 && echo clean || echo dirty)"
  }
}
EOF
echo "pre-upgrade-check: snapshot written to $OUT" >&2
[[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]] && \
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" --event "pre-upgrade.snapshot" \
    --severity "info" --field "snapshot_path=$OUT" 2>/dev/null || true
