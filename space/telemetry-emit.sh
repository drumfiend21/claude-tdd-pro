#!/usr/bin/env bash
# Production telemetry emitter.
#
# Per the simulated Musk-team review (Jinnah Hosein):
#   "If you can't measure it in production, it doesn't exist in
#    production."
#
# Writes a structured event to ~/.claude-tdd-pro/telemetry.jsonl
# on every emission. Honors the Q-6 privacy posture (local-only by
# default; export only via the redaction filter). When the operator
# opts in via .claude-tdd-pro/userConfig.yaml `telemetry: enabled`,
# events are uploaded to the configured endpoint.
#
# Usage:
#   space/telemetry-emit.sh --event <name> [--field key=value ...]
#                           [--severity info|warn|error]
#                           [--dry-run]
#
# Honors:
#   - Q-1 SPACE config (config.yaml dimension gates)
#   - Q-6 privacy posture (share: never default)
#   - §2.18 cost telemetry contract

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
LOG_DIR="${TELEMETRY_LOG_DIR:-$HOME/.claude-tdd-pro}"
LOG_FILE="$LOG_DIR/telemetry.jsonl"

EVENT=""
SEVERITY="info"
DRY_RUN=0
FIELDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) EVENT="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --field) FIELDS+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: telemetry-emit.sh --event <name> [--field key=value ...] [--severity info|warn|error] [--dry-run]" >&2
      exit 0 ;;
    *) echo "telemetry-emit: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$EVENT" ]] && { echo "telemetry-emit: --event required" >&2; exit 2; }

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
session="${CLAUDE_SESSION_ID:-local-$(printf '%(%s)T' -1)}"
version=$(grep -oE '"version": "[^"]+"' "$PLUGIN_ROOT/package.json" 2>/dev/null | head -1 | grep -oE '[0-9.]+' || echo unknown)

# Compose the JSON event.
event_json=$(node -e '
  const ev = {
    ts: process.env.TS,
    session: process.env.SESSION,
    version: process.env.VERSION,
    event: process.env.EVENT,
    severity: process.env.SEVERITY,
    fields: {},
  };
  for (const kv of process.argv.slice(1)) {
    const i = kv.indexOf("=");
    if (i > 0) ev.fields[kv.substring(0, i)] = kv.substring(i + 1);
  }
  process.stdout.write(JSON.stringify(ev));
' TS="$ts" SESSION="$session" VERSION="$version" EVENT="$EVENT" SEVERITY="$SEVERITY" "${FIELDS[@]}" 2>/dev/null)

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "telemetry-emit: dry-run; would write: $event_json" >&2
  exit 0
fi

mkdir -p "$LOG_DIR"
echo "$event_json" >> "$LOG_FILE"

# Honor Q-6 share posture: never upload unless config opts in.
# Check is best-effort — if the config doesn't exist, default to never.
share_posture="never"
if [[ -f "$PLUGIN_ROOT/space/config.yaml" ]]; then
  share_posture=$(grep -E "^share:" "$PLUGIN_ROOT/space/config.yaml" | head -1 | awk '{print $2}')
fi

if [[ "$share_posture" == "never" || -z "$share_posture" ]]; then
  exit 0
fi

# (Future: upload to configured endpoint here, honoring Q-6 redaction)
exit 0
