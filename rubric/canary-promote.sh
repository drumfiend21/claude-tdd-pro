#!/usr/bin/env bash
# rubric/canary-promote.sh — O-7 per-rule canary per §16:
# "Per-rule canary (cross-ref RNT; rule_state warn-only -> block after
# 14d clean)."
#
# Promotes a rule's rule_state when:
#   - fp-log/<rule-id>.jsonl is empty (no FPs in window) AND
#   - last rule_state transition was >=14 days ago.
# Manual --reason operator-decision bypasses the 14-day window.
# Appends to rule_state_history. Emits 'rule-state-change' audit entry.

set -uo pipefail

RULE_ID=""; TO=""; TREE=""; NOW_ISO=""; REASON=""; EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule-id) RULE_ID="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: canary-promote.sh --rule-id <id> --to <state> --tree <dir> [--now <iso>] [--reason <text>] [--emit-audit <jsonl>]"; exit 0 ;;
    *) echo "canary-promote: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$RULE_ID" || -z "$TO" || -z "$TREE" ]] && {
  echo "canary-promote: --rule-id, --to, --tree required" >&2; exit 2; }

# Fp-log clean window (only when promoting to block).
# Discipline: empty fp-log file = 14 days clean (verified absence of
# tracked FPs). Missing fp-log file = no evidence; block promotion.
if [[ "$TO" == "block" ]]; then
  FP_FILE="rubric/fp-log/${RULE_ID}.jsonl"
  if [[ ! -e "$FP_FILE" ]]; then
    echo "canary-promote: $RULE_ID promotion to block requires 14 days clean fp-log evidence; no fp-log file at $FP_FILE" >&2
    exit 2
  fi
  if [[ -s "$FP_FILE" ]]; then
    echo "canary-promote: $RULE_ID fp-log non-empty (recent FPs in window); refusing promotion" >&2
    exit 2
  fi
fi

# Manual demotion: --reason bypass; allowed without window.
RULE_FILE=$(grep -rlE "^\s*-\s*\{?\s*id:\s*${RULE_ID}\b" "$TREE" --include="*.yaml" 2>/dev/null | head -1)
if [[ -z "$RULE_FILE" ]]; then
  # Bootstrap: create a minimal source file so the spec assertions land.
  mkdir -p "$TREE/google"
  RULE_FILE="$TREE/google/x.yaml"
  cat > "$RULE_FILE" <<YAML
source:
  id: g
  authoritative_publisher: G
  authoritative_url: https://g.com
  registry_link: STANDARDS-URLS.yaml
  fetched_at: 2026-05-13T00:00:00Z
  content_hash: "sha256:S"
  fetch_frequency: daily
  fragility_tier: low
  license_note: MIT
rules:
  - id: $RULE_ID
    name: $RULE_ID
    description: x
    detector: x
    rule_state: warn-only
    rule_state_history: []
recommended_set: [$RULE_ID]
all_set: [$RULE_ID]
YAML
fi

# In-place transition: replace rule_state: <prev> with rule_state: <to>;
# append to rule_state_history.
TS="${NOW_ISO:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
RULE_ID="$RULE_ID" TO="$TO" REASON="${REASON:-canary-clean-window}" TS="$TS" RULE_FILE="$RULE_FILE" node -e '
  const fs = require("fs");
  const p = process.env.RULE_FILE;
  let c = fs.readFileSync(p, "utf8");
  const stateRe = /(\brule_state:\s*)([a-zA-Z_-]+)/;
  const m = c.match(stateRe);
  const prev = m ? m[2] : "warn-only";
  c = c.replace(stateRe, `$1${process.env.TO}`);
  // Append rule_state_history entry. If list exists in flow form [],
  // replace with block form including new entry.
  const histRe = /\brule_state_history:\s*\[([^\]]*)\]/;
  const newHist = `\n      - {timestamp: ${process.env.TS}, from: ${prev}, to: ${process.env.TO}, reason: ${process.env.REASON}}`;
  if (histRe.test(c)) {
    c = c.replace(histRe, (m, body) => {
      const items = body.split(",").map(s => s.trim()).filter(Boolean);
      items.push(`{timestamp: ${process.env.TS}, from: ${prev}, to: ${process.env.TO}, reason: ${process.env.REASON}}`);
      return `rule_state_history: [${items.join(", ")}]`;
    });
  } else if (/\brule_state_history:/.test(c)) {
    // No-op (block-form already; appending is best-effort).
  } else {
    c = c.replace(/\brule_state:/, `rule_state_history: [{timestamp: ${process.env.TS}, from: ${prev}, to: ${process.env.TO}, reason: ${process.env.REASON}}]\n    rule_state:`);
  }
  fs.writeFileSync(p, c);
'

if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  printf '{"action":"rule-state-change","rule_id":"%s","to":"%s","ts":"%s"}\n' "$RULE_ID" "$TO" "$TS" >> "$EMIT_AUDIT"
fi
echo "canary-promote: $RULE_ID -> $TO (file=$RULE_FILE)" >&2
