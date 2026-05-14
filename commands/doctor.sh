#!/usr/bin/env bash
# /doctor — health-check command. Initial substrate handles G-12 routing only;
# extended in subsequent CLs to cover H-1 token-cost transparency, H-7 --watch
# monitor, multi-language coverage check (H-5), and others.
#
# Usage:
#   bash doctor.sh --check validate-all --root <dir>
#
# Per detector contract §2.2:
#   exit 0 → check passed
#   exit 1 → check failed
#   exit 2 → tooling/usage error

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
CHECK=""
ROOT=""
SIMULATE_CURRENT_TOKENS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --simulate-current-tokens) SIMULATE_CURRENT_TOKENS="$2"; shift 2 ;;
    -h|--help) sed -n '1,15p' "$0" | grep -E '^# ' | sed 's/^# //'; exit 0 ;;
    *) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$CHECK" ]] && { echo "doctor: --check <name> required" >&2; exit 2; }

case "$CHECK" in
  validate-all)
    [[ -z "$ROOT" ]] && { echo "doctor: --check validate-all requires --root <dir>" >&2; exit 2; }
    if bash "$PLUGIN_ROOT/generated-code-quality-standards/validate-all.sh" --root "$ROOT" --format text 2>/dev/null; then
      echo "validate-all: ok" >&2
      exit 0
    else
      echo "validate-all: fail" >&2
      exit 1
    fi
    ;;
  directory-layout)
    # G-1: verify the 14 default namespace folders + _operator/_community/_meta exist
    [[ -z "$ROOT" ]] && ROOT="$PLUGIN_ROOT/generated-code-quality-standards"
    REQUIRED=(google us-government european-union finance-industry owasp w3c web-vitals react node typescript slsa linux-foundation industry-self-regulatory _universal _operator _community _meta)
    MISSING=()
    for ns in "${REQUIRED[@]}"; do
      [[ -d "$ROOT/$ns" ]] || MISSING+=("$ns")
    done
    if [[ ${#MISSING[@]} -eq 0 ]]; then
      echo "directory-layout: ok" >&2
      exit 0
    else
      echo "directory-layout: fail (missing: ${MISSING[*]})" >&2
      exit 1
    fi
    ;;
  telemetry-drift)
    # O-0: compare current measured tokens-per-turn against pinned baseline.
    # >20% drift surfaces a warning. Used by /doctor and CI.
    BASELINE="${PWD}/.claude-tdd-pro/telemetry-baseline.json"
    [[ ! -f "$BASELINE" ]] && { echo "telemetry-drift: no baseline at $BASELINE" >&2; exit 1; }
    [[ -z "$SIMULATE_CURRENT_TOKENS" ]] && { echo "telemetry-drift: --simulate-current-tokens <N> required" >&2; exit 2; }
    BASELINE="$BASELINE" CURRENT="$SIMULATE_CURRENT_TOKENS" node -e '
      const fs = require("fs");
      const b = JSON.parse(fs.readFileSync(process.env.BASELINE, "utf8"));
      const current = parseInt(process.env.CURRENT, 10);
      // Find first skill with a tokens_per_turn baseline > 0
      let baselineTokens = null;
      for (const k of Object.keys(b.skills || {})) {
        const t = (b.skills[k] || {}).tokens_per_turn;
        if (typeof t === "number" && t > 0) { baselineTokens = t; break; }
      }
      if (baselineTokens === null) {
        process.stderr.write("telemetry-drift: no measured baseline tokens to compare against\n");
        process.exit(0);
      }
      const driftPct = Math.round(((current - baselineTokens) / baselineTokens) * 100);
      const sign = driftPct >= 0 ? "+" : "";
      process.stderr.write(`telemetry-drift: baseline=${baselineTokens} current=${current} drift=${sign}${driftPct}%\n`);
      if (Math.abs(driftPct) > 20) {
        process.stderr.write(`telemetry-drift: WARNING drift exceeds 20% threshold\n`);
      }
    '
    echo "ok" >&2
    exit 0
    ;;
  *)
    echo "doctor: unknown check: $CHECK" >&2
    exit 2
    ;;
esac
