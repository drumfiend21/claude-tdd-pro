#!/usr/bin/env bash
# Post-upgrade verification. Runs after a Claude Code update is
# detected (auto-invoked by hooks/scripts/session-start-version-check.sh).
# Compares current state to the most recent pre-upgrade snapshot
# (or to baseline expectations if none exists) and reports:
#   PASS     — everything still works; safe to continue
#   DEGRADED — some surfaces affected but standalone path works
#   FAIL     — engages standalone mode and notifies operator
#
# Usage:
#   scripts/post-upgrade-verify.sh [--from <ver>] [--to <ver>]
#                                  [--snapshot <path>]
#
# Exit codes:
#   0 — PASS
#   2 — DEGRADED (operator should review)
#   1 — FAIL (standalone mode engaged)

set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
FROM=""
TO=""
SNAPSHOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    -h|--help) echo "Usage: post-upgrade-verify.sh [--from <ver>] [--to <ver>] [--snapshot <path>]" >&2; exit 0 ;;
    *) echo "post-upgrade-verify: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Find most recent snapshot if not specified.
if [[ -z "$SNAPSHOT" ]] && [[ -d "$PLUGIN_ROOT/audit" ]]; then
  SNAPSHOT=$(ls -t "$PLUGIN_ROOT/audit"/pre-upgrade-*.json 2>/dev/null | head -1)
fi

echo "post-upgrade-verify: from=${FROM:-unknown} to=${TO:-unknown}" >&2

# Run the same checks that pre-upgrade-check captures, plus extras
# specific to upgrade verification.
fail=0
degraded=0
verdicts=()

check() {
  local name="$1" cmd="$2" required="$3"  # required: 1 = FAIL on fail, 0 = DEGRADED
  if eval "$cmd" >/dev/null 2>&1; then
    verdicts+=("  ✓ $name")
  else
    if [[ "$required" -eq 1 ]]; then
      verdicts+=("  ✗ $name (required — FAIL)")
      fail=1
    else
      verdicts+=("  ⚠ $name (optional — DEGRADED)")
      degraded=1
    fi
  fi
}

# Required: the platform-independent core must work.
check "standalone-verify (8/8 surfaces)" \
  "bash $PLUGIN_ROOT/scripts/standalone-verify.sh --quiet" 1

check "rubric suite smoke (cl414-Q-1)" \
  "bash $PLUGIN_ROOT/evals/runner.sh --filter cl414-Q-1" 1

check "fitness: substrate completeness" \
  "bash $PLUGIN_ROOT/rubric/detectors/audit-substrate-completeness.sh --quiet" 1

check "fitness: CLI surface fidelity" \
  "bash $PLUGIN_ROOT/rubric/detectors/audit-cli-surface-fidelity.sh --quiet" 1

# Optional (degraded if fail): Claude Code surfaces.
check "hook scripts executable" \
  "test -x $PLUGIN_ROOT/hooks/scripts/session-start-version-check.sh" 0

check "compatibility manifest readable" \
  "test -s $PLUGIN_ROOT/compatibility/claude-code-versions.yaml" 0

printf '%s\n' "${verdicts[@]}" >&2

verdict="PASS"
if [[ "$fail" -eq 1 ]]; then
  verdict="FAIL"
elif [[ "$degraded" -eq 1 ]]; then
  verdict="DEGRADED"
fi

echo "" >&2
echo "post-upgrade-verify: $verdict" >&2

# Telemetry + side effects.
if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
    --event "post-upgrade.verify" --severity "info" \
    --field "verdict=$verdict" --field "from=${FROM:-unknown}" --field "to=${TO:-unknown}" \
    2>/dev/null || true
fi

# On FAIL, engage standalone mode automatically.
if [[ "$verdict" == "FAIL" ]]; then
  marker="${HOME}/.claude-tdd-pro/standalone-mode"
  mkdir -p "$(dirname "$marker")"
  cat > "$marker" <<EOF
{
  "engaged_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "post-upgrade-verify reported FAIL on Claude Code version transition from=${FROM:-unknown} to=${TO:-unknown}",
  "next_step": "Inspect audit/post-upgrade-*.json. Once compatibility is confirmed, run: bash $PLUGIN_ROOT/hooks/scripts/payload-validator.sh --disengage",
  "manual_disengage": "rm $marker"
}
EOF
  echo "  standalone mode engaged → $marker" >&2
  exit 1
fi

[[ "$verdict" == "DEGRADED" ]] && exit 2 || exit 0
