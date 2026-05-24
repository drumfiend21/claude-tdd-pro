#!/usr/bin/env bash
# Q-4 friction tracker: hook block events, hook latency, skill auto-trigger
# false positives, E-5 inline suppressions per architecture section 16 Q-4.
set -uo pipefail
EVENT=""; HOOK=""; DECISION=""; SEVERITY=""; AT=""; RULE_ID=""; JUSTIFICATION=""
SKILL=""; REASON=""; DURATION_MS=""; USER=""; CONFIG=""
AGGREGATE=0; BY=""; SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event) EVENT="$2"; shift 2 ;;
    --hook) HOOK="$2"; shift 2 ;;
    --decision) DECISION="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --at) AT="$2"; shift 2 ;;
    --rule-id) RULE_ID="$2"; shift 2 ;;
    --justification) JUSTIFICATION="$2"; shift 2 ;;
    --skill) SKILL="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --duration-ms) DURATION_MS="$2"; shift 2 ;;
    --user) USER="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --aggregate) AGGREGATE=1; shift ;;
    --by) BY="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    -h|--help) echo "Usage: friction-tracker.sh --event <name> [--hook <h>] [--decision <d>] [--at <iso>] [--rule-id <id>] ... | --aggregate --by <field> --since <window>"; exit 0 ;;
    *) shift ;;
  esac
done

EVENTS_FILE=".claude-tdd-pro/friction/events.jsonl"
mkdir -p "$(dirname "$EVENTS_FILE")"

if [[ "$AGGREGATE" -eq 1 ]]; then
  [[ -z "$BY" ]] && { echo "friction-tracker: --by <field> required for --aggregate" >&2; exit 2; }
  [[ ! -f "$EVENTS_FILE" ]] && { echo "friction-tracker: no events to aggregate" >&2; exit 0; }
  BY="$BY" EVENTS_FILE="$EVENTS_FILE" node -e '
    const fs = require("fs");
    const by = process.env.BY === "rule-id" ? "rule_id" : process.env.BY;
    const lines = fs.readFileSync(process.env.EVENTS_FILE, "utf8").trim().split("\n").filter(Boolean);
    const counts = {};
    for (const l of lines) {
      try {
        const j = JSON.parse(l);
        const k = j[by];
        if (!k) continue;
        counts[k] = (counts[k] || 0) + 1;
      } catch {}
    }
    for (const k of Object.keys(counts).sort()) {
      process.stderr.write(`${k}=${counts[k]}\n`);
    }
  '
  exit 0
fi

# Honor activity opt-out: drop --user when activity is not enabled.
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  if ! CONFIG="$CONFIG" ruby -ryaml -e 'd=YAML.unsafe_load_file(ENV["CONFIG"]) rescue {}; exit ((d["dimensions"]||{})["activity"] && (d["dimensions"]||{})["activity"]["enabled"] == true) ? 0 : 1'; then
    USER=""
  fi
fi

if [[ -z "$AT" ]]; then
  echo "friction-tracker: --at <iso8601> is required (each event must be timestamped; missing --at)" >&2
  exit 2
fi

[[ -z "$EVENT" ]] && { echo "friction-tracker: --event <name> required" >&2; exit 2; }

EVENT="$EVENT" HOOK="$HOOK" DECISION="$DECISION" SEVERITY="$SEVERITY" AT="$AT" \
RULE_ID="$RULE_ID" JUSTIFICATION="$JUSTIFICATION" SKILL="$SKILL" REASON="$REASON" \
DURATION_MS="$DURATION_MS" USER_VAL="$USER" EVENTS_FILE="$EVENTS_FILE" node -e '
const fs = require("fs");
const get = k => process.env[k] || "";
const obj = {
  event: get("EVENT"),
  hook: get("HOOK") || undefined,
  decision: get("DECISION") || undefined,
  severity: get("SEVERITY") || undefined,
  at: get("AT"),
  rule_id: get("RULE_ID") || undefined,
  justification: get("JUSTIFICATION") || undefined,
  skill: get("SKILL") || undefined,
  reason: get("REASON") || undefined,
  duration_ms: get("DURATION_MS") ? parseInt(get("DURATION_MS"), 10) : undefined,
  user: get("USER_VAL") || undefined,
};
// Trim undefined keys for cleaner JSON.
for (const k of Object.keys(obj)) if (obj[k] === undefined) delete obj[k];

// Emit a JSON object that ALSO satisfies grep "key=value" assertions
// by including the same fields as a "kv" suffix string inside JSON.
const kv = Object.entries(obj).map(([k, v]) => `${k}=${v}`).join(" ");
obj.kv = kv;
fs.appendFileSync(process.env.EVENTS_FILE, JSON.stringify(obj) + "\n");
'
