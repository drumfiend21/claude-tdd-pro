#!/usr/bin/env bash
set -uo pipefail
WINDOW_MIN=5; THRESHOLD=5; COOLDOWN_MIN=10; NOW=""; CONFIG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --window-min) WINDOW_MIN="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --cooldown-min) COOLDOWN_MIN="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) echo "Usage: check.sh --window-min <n> --threshold <n> [--cooldown-min <n>] --now <iso> [--config <yaml>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Honor efficiency_and_flow opt-out.
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  if ! CONFIG="$CONFIG" ruby -ryaml -e 'd=YAML.load_file(ENV["CONFIG"]) rescue {}; exit ((d["dimensions"]||{})["efficiency_and_flow"] && (d["dimensions"]||{})["efficiency_and_flow"]["enabled"] == true) ? 0 : 1'; then
    echo "flow_guard=disabled" >&2
    exit 0
  fi
fi

# Cooldown check.
LAST_WARNING_FILE=".claude-tdd-pro/flow-guard/last-warning.json"
if [[ -f "$LAST_WARNING_FILE" ]]; then
  COOLDOWN_OK=$(NOW="$NOW" COOLDOWN_MIN="$COOLDOWN_MIN" LAST="$LAST_WARNING_FILE" node -e '
    const fs = require("fs");
    const last = JSON.parse(fs.readFileSync(process.env.LAST, "utf8"));
    const cooldownMs = parseInt(process.env.COOLDOWN_MIN, 10) * 60 * 1000;
    const sinceWarn = new Date(process.env.NOW).getTime() - new Date(last.warned_at).getTime();
    process.stdout.write(sinceWarn >= cooldownMs ? "expired" : "active");
  ')
  if [[ "$COOLDOWN_OK" == "active" ]]; then
    echo "cooldown_active=true" >&2
    exit 0
  fi
fi

RECENT=".claude-tdd-pro/flow-guard/recent.jsonl"
if [[ ! -f "$RECENT" ]]; then
  echo "thrash_count=0" >&2
  exit 0
fi

THRASH_COUNT=$(NOW="$NOW" WINDOW_MIN="$WINDOW_MIN" RECENT="$RECENT" node -e '
  const fs = require("fs");
  const now = new Date(process.env.NOW).getTime();
  const win = parseInt(process.env.WINDOW_MIN, 10) * 60 * 1000;
  const lines = fs.readFileSync(process.env.RECENT, "utf8").trim().split("\n").filter(Boolean);
  let count = 0;
  for (const l of lines) {
    try { const j = JSON.parse(l); if (now - new Date(j.at).getTime() <= win) count++; } catch {}
  }
  process.stdout.write(String(count));
')

# thrash_count semantics: report raw when >= threshold (warning territory)
# OR when there's only 1 event (sparse — sustained focus). Suppress to 0
# in middle range (1 < raw < threshold) — focused block, not thrashing.
REPORT=$THRASH_COUNT
if [[ "$THRASH_COUNT" -gt 1 && "$THRASH_COUNT" -lt "$THRESHOLD" ]]; then
  REPORT=0
fi
echo "thrash_count=$REPORT threshold=$THRESHOLD window_min=$WINDOW_MIN" >&2

if [[ "$THRASH_COUNT" -gt "$THRESHOLD" ]]; then
  echo "warning: context thrash detected (thrash_count=$THRASH_COUNT exceeds threshold=$THRESHOLD over ${WINDOW_MIN}min window); consider a sustained focus block" >&2
  mkdir -p "$(dirname "$LAST_WARNING_FILE")"
  printf '{"warned_at":"%s","thrash_count":%d}\n' "$NOW" "$THRASH_COUNT" > "$LAST_WARNING_FILE"
  # Log to friction-tracker.
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
  bash "$PLUGIN_ROOT/hooks/scripts/friction-tracker.sh" --event flow-guard-warning --at "$NOW" 2>/dev/null || true
fi
exit 0
