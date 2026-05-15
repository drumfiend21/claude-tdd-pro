#!/usr/bin/env bash
# control-mapping-gate.sh — C-18 substrate. Live freshness gate on
# control mapping activation per architecture section 16 C-18.
set -uo pipefail

FRAMEWORK=""
CONTROL_ID=""
FETCH_FREQUENCY="weekly"
NOW=""
EMIT_STATUS=""
EMIT_AUDIT=""
PAYWALLED=0
CONTROLS_FILE=""
APPLY_TO_CONTROLS=0
STRICT=0
SKIP_FRESH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --control-id) CONTROL_ID="$2"; shift 2 ;;
    --fetch-frequency) FETCH_FREQUENCY="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --emit-status) EMIT_STATUS="$2"; shift 2 ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    --paywalled) PAYWALLED=1; shift ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --apply-to-controls) APPLY_TO_CONTROLS=1; shift ;;
    --strict) STRICT=1; shift ;;
    --skip-fresh) SKIP_FRESH=1; shift ;;
    -h|--help)
      echo "Usage: control-mapping-gate.sh --framework <id> --control-id <id> [--fetch-frequency <freq>] [--now <iso>] [--emit-status <path>] [--emit-audit <path>] [--paywalled] [--skip-fresh] [--strict] [--controls-file <path> --apply-to-controls]"
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

emit_status() {
  local fw="$1" status="$2"
  if [[ -n "$EMIT_STATUS" ]]; then
    mkdir -p "$(dirname "$EMIT_STATUS")"
    printf '{"%s":{"freshness_at_generation":"%s","gated_at":"%s"}}\n' "$fw" "$status" "$NOW" > "$EMIT_STATUS"
  fi
}

emit_audit() {
  local fw="$1" outcome="$2" reason="$3"
  if [[ -n "$EMIT_AUDIT" ]]; then
    mkdir -p "$(dirname "$EMIT_AUDIT")"
    printf '{"event":"control-mapping-gate","framework":"%s","control_id":"%s","outcome":"%s","reason":"%s","at":"%s"}\n' "$fw" "$CONTROL_ID" "$outcome" "$reason" "$NOW" >> "$EMIT_AUDIT"
  fi
}

check_freshness() {
  local fw="$1"
  local last_fetch_file=".claude-tdd-pro/compliance-last-fetch/$fw.txt"
  if [[ ! -f "$last_fetch_file" ]]; then echo "no-fetch-record"; return; fi
  local last_fetch=$(cat "$last_fetch_file" | tr -d ' \n')
  NOW_TS=$NOW LAST_TS=$last_fetch FREQ=$FETCH_FREQUENCY node -e '
    const now = new Date(process.env.NOW_TS).getTime();
    const last = new Date(process.env.LAST_TS).getTime();
    const freq = process.env.FREQ;
    const ms = { hourly: 3600e3, daily: 86400e3, weekly: 7*86400e3, monthly: 30*86400e3, quarterly: 90*86400e3 }[freq] || 7*86400e3;
    process.stdout.write((now - last) <= ms ? "fresh-within-fetch-frequency" : "stale-beyond-fetch-frequency");
  '
}

# Apply-to-controls mode: scan controls.yaml and demote/restore.
if [[ "$APPLY_TO_CONTROLS" -eq 1 && -n "$CONTROLS_FILE" ]]; then
  CONTROLS_FILE="$CONTROLS_FILE" NOW="$NOW" STRICT="$STRICT" node -e '
    const fs = require("fs");
    const path = require("path");
    const cf = process.env.CONTROLS_FILE;
    const now = process.env.NOW;
    const strict = process.env.STRICT === "1";
    const demotionsFile = ".claude-tdd-pro/control-demotions.json";
    let demotions = {};
    if (fs.existsSync(demotionsFile)) try { demotions = JSON.parse(fs.readFileSync(demotionsFile, "utf8")); } catch {}

    let body = fs.readFileSync(cf, "utf8");
    const blocks = body.split(/^- /m).slice(1);
    let out = "";
    for (const blk of blocks) {
      const fwM = blk.match(/framework:\s*(\S+)/);
      const cidM = blk.match(/control_id:\s*(\S+)/);
      const stM = blk.match(/legal_review_status:\s*(\S+)/);
      const fw = fwM && fwM[1], cid = cidM && cidM[1], st = stM && stM[1];
      const lastFile = `.claude-tdd-pro/compliance-last-fetch/${fw}.txt`;
      let stale = true;
      if (fs.existsSync(lastFile)) {
        const last = fs.readFileSync(lastFile, "utf8").trim();
        const diff = new Date(now).getTime() - new Date(last).getTime();
        if (diff <= 7*86400e3) stale = false;
      }
      const key = `${fw}:${cid}`;
      let newStatus = st;
      if (stale && st !== "pending-stale-source" && st !== "disabled") {
        if (strict) {
          newStatus = "disabled";
        } else {
          demotions[key] = { original: st, demoted: "pending-stale-source" };
          newStatus = "pending-stale-source";
        }
      } else if (!stale && demotions[key]) {
        newStatus = demotions[key].original;
        delete demotions[key];
      }
      let newBlk = blk.replace(/legal_review_status:\s*\S+/, `legal_review_status: ${newStatus}`);
      out += "- " + newBlk;
    }
    fs.writeFileSync(cf, out);
    fs.mkdirSync(path.dirname(demotionsFile), { recursive: true });
    fs.writeFileSync(demotionsFile, JSON.stringify(demotions));
    process.stderr.write(`control-mapping-gate: apply-to-controls done\n`);
  '
  exit 0
fi

# Single-control gate mode.
[[ -z "$FRAMEWORK" || -z "$CONTROL_ID" ]] && { echo "control-mapping-gate: --framework and --control-id required" >&2; exit 2; }

# Paywalled framework requires attestation.
if [[ "$PAYWALLED" -eq 1 ]]; then
  ATTEST="compliance/attestations/$FRAMEWORK.yaml"
  if [[ ! -f "$ATTEST" ]]; then
    echo "control-mapping-gate: paywalled framework $FRAMEWORK requires attestation at $ATTEST (license proof)" >&2
    emit_audit "$FRAMEWORK" "blocked" "missing-attestation"
    exit 1
  fi
fi

STATUS=$(check_freshness "$FRAMEWORK")
emit_status "$FRAMEWORK" "$STATUS"

if [[ "$STATUS" == "fresh-within-fetch-frequency" ]]; then
  echo "control-mapping-gate: $FRAMEWORK control $CONTROL_ID PASS (fresh)" >&2
  emit_audit "$FRAMEWORK" "pass" "fresh"
  exit 0
fi

if [[ "$SKIP_FRESH" -eq 1 ]]; then
  echo "control-mapping-gate: $FRAMEWORK control $CONTROL_ID BYPASS via --skip-fresh (per section 2.17)" >&2
  emit_audit "$FRAMEWORK" "bypass" "skip-fresh"
  exit 0
fi

echo "control-mapping-gate: $FRAMEWORK control $CONTROL_ID BLOCKED ($STATUS / stale beyond fetch_frequency=$FETCH_FREQUENCY)" >&2
emit_audit "$FRAMEWORK" "blocked" "stale"
# When --emit-audit is set, treat as informational mode (the audit
# entry captures the decision; the caller decides whether to enforce).
# Without --emit-audit, gate enforces by exiting 1.
[[ -n "$EMIT_AUDIT" ]] && exit 0
exit 1
