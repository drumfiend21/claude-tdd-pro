#!/usr/bin/env bash
# secret-scan.sh — rubric-runner adapter that delegates to the existing
# hardened secret-scan in hooks/scripts/secret-scan.sh. Outputs JSON-line
# findings for the rubric-runner.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RULE_ID="${RULE_ID:-g-sec-001-no-secrets}"
SEVERITY="${SEVERITY:-P0}"

scan_script="${PLUGIN_ROOT}/hooks/scripts/secret-scan.sh"
if [[ ! -x "$scan_script" ]]; then
  printf '{"rule":"%s","severity":"SKIP","file":"","line":0,"msg":"secret-scan.sh not executable"}\n' "$RULE_ID"
  exit 0
fi

# The existing secret-scan exits non-zero on a hit and prints to stderr.
# Capture both, normalize to JSON-line.
out="$( "$scan_script" 2>&1 || true )"
rc=$?
if [[ $rc -ne 0 || -n "$out" ]]; then
  msg="$(echo "$out" | tr '\n' ' ' | sed 's/  */ /g')"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"%s"}\n' \
    "$RULE_ID" "$SEVERITY" "${msg//\"/\\\"}"
fi
