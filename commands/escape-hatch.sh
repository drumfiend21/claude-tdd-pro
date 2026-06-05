#!/usr/bin/env bash
# Escape hatch — explicit bypass for senior engineers during
# production fires.
#
# Per the Musk Engineering Leadership review:
#   "Add explicit 'escape hatch' for senior engineers who need to
#    bypass for urgent production fires (with mandatory /remember
#    logging)."
#
# Discipline:
#   - Operator must provide --justification "<text>" (mandatory).
#   - Operator must type "I-UNDERSTAND-THE-RISK" at the prompt
#     (cannot be invoked from a script alone).
#   - Every invocation appends to audit/escape-hatch-log.jsonl
#     (append-only; entries include sha256 chain to prior entry).
#   - The audit log is required reading in the next CL post-fire.
#
# Usage:
#   commands/escape-hatch.sh --justification "<text>" \
#                            --bypass <hook-name|all> \
#                            [--duration-min N] \
#                            [--ticket <id>]
#
# What it does:
#   1. Records justification + timestamp + operator + bypassed-hook
#      to audit/escape-hatch-log.jsonl with sha256 chain.
#   2. Sets ESCAPE_HATCH_ACTIVE env var that hooks read to skip
#      themselves for the duration.
#   3. After --duration-min minutes (default 30), the env-var-file
#      auto-expires and hooks resume normal operation.
#   4. Emits telemetry events (escape-hatch.engaged / .expired) for
#      operator-visible audit.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
AUDIT_LOG="${PLUGIN_ROOT}/audit/escape-hatch-log.jsonl"
ENV_FILE="${HOME}/.claude-tdd-pro/escape-hatch-active"

JUSTIFICATION=""
BYPASS=""
DURATION_MIN=30
TICKET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --justification) JUSTIFICATION="$2"; shift 2 ;;
    --bypass) BYPASS="$2"; shift 2 ;;
    --duration-min) DURATION_MIN="$2"; shift 2 ;;
    --ticket) TICKET="$2"; shift 2 ;;
    --status)
      if [[ -f "$ENV_FILE" ]]; then
        cat "$ENV_FILE" >&2
        exit 0
      else
        echo "escape-hatch: not active" >&2
        exit 1
      fi ;;
    -h|--help)
      cat >&2 <<USAGE
Usage: escape-hatch.sh --justification "<text>" --bypass <hook|all>
                       [--duration-min N] [--ticket <id>]
       escape-hatch.sh --status

This command BYPASSES the plugin's quality gates. Use only during
production fires when normal CL discipline cannot fit the recovery
window. Every invocation is audit-logged and read in the next CL.

Required:
  --justification <text>  Why this fire requires the bypass.
                          Logged verbatim to audit chain.
  --bypass <hook|all>     Which guard to disable. Use 'all' for
                          full bypass (logs as P0 incident).

Optional:
  --duration-min N        Auto-expire after N minutes (default 30).
  --ticket <id>           Tie the bypass to a ticket/incident.

Interactive:
  Operator must type "I-UNDERSTAND-THE-RISK" at the prompt.
USAGE
      exit 0 ;;
    *) echo "escape-hatch: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$JUSTIFICATION" || -z "$BYPASS" ]]; then
  echo "escape-hatch: --justification and --bypass are mandatory" >&2
  echo "  run with --help for the full discipline" >&2
  exit 2
fi

# Hard-block bypass-from-script: require operator-typed confirm.
if [[ -t 0 ]] || [[ -e /dev/tty ]]; then
  echo "" >&2
  echo "BYPASSING PLUGIN QUALITY GATES" >&2
  echo "  justification: $JUSTIFICATION" >&2
  echo "  bypass:        $BYPASS" >&2
  echo "  duration:      ${DURATION_MIN} minutes" >&2
  [[ -n "$TICKET" ]] && echo "  ticket:        $TICKET" >&2
  echo "" >&2
  echo "Type 'I-UNDERSTAND-THE-RISK' to confirm." >&2
  if [[ -t 0 ]]; then read -r CONFIRM
  else read -r CONFIRM < /dev/tty 2>/dev/null || CONFIRM=""
  fi
  if [[ "$CONFIRM" != "I-UNDERSTAND-THE-RISK" ]]; then
    echo "escape-hatch: confirmation not provided; bypass aborted" >&2
    exit 1
  fi
else
  echo "escape-hatch: no TTY available; bypass-from-script not allowed" >&2
  echo "  (this prevents an attacker from invoking the hatch via a hook)" >&2
  exit 1
fi

# Compute audit-chain prior hash.
prior_hash="genesis"
if [[ -f "$AUDIT_LOG" ]]; then
  prior_hash=$(tail -1 "$AUDIT_LOG" 2>/dev/null \
    | node -e 'try { const l=require("fs").readFileSync(0,"utf8").trim(); process.stdout.write(JSON.parse(l).entry_sha256 || "missing"); } catch { process.stdout.write("err"); }' \
    2>/dev/null || echo "err")
fi

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
expires=$(date -u -d "+${DURATION_MIN} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u +%Y-%m-%dT%H:%M:%SZ)
operator=$(git config user.email 2>/dev/null || echo "${USER:-unknown}")

# Emit audit-chain entry (signed via sha256 of canonical fields).
mkdir -p "$(dirname "$AUDIT_LOG")"
entry=$(JUSTIFICATION="$JUSTIFICATION" BYPASS="$BYPASS" \
        DURATION_MIN="$DURATION_MIN" TICKET="$TICKET" \
        TS="$ts" EXPIRES="$expires" OPERATOR="$operator" \
        PRIOR_HASH="$prior_hash" \
        node -e '
  const crypto = require("crypto");
  const obj = {
    ts: process.env.TS,
    expires: process.env.EXPIRES,
    operator: process.env.OPERATOR,
    bypass: process.env.BYPASS,
    duration_min: parseInt(process.env.DURATION_MIN, 10),
    ticket: process.env.TICKET || null,
    justification: process.env.JUSTIFICATION,
    prior_hash: process.env.PRIOR_HASH,
  };
  const canonical = JSON.stringify(obj, Object.keys(obj).sort());
  obj.entry_sha256 = crypto.createHash("sha256").update(canonical).digest("hex");
  process.stdout.write(JSON.stringify(obj));
')
echo "$entry" >> "$AUDIT_LOG"

# Write the active-bypass marker file (hooks read this).
mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
ESCAPE_HATCH_BYPASS=$BYPASS
ESCAPE_HATCH_EXPIRES=$expires
ESCAPE_HATCH_OPERATOR=$operator
ESCAPE_HATCH_TICKET=${TICKET:-none}
EOF

# Telemetry emission.
if [[ -x "$PLUGIN_ROOT/space/telemetry-emit.sh" ]]; then
  bash "$PLUGIN_ROOT/space/telemetry-emit.sh" \
    --event "escape-hatch.engaged" --severity "warn" \
    --field "bypass=$BYPASS" --field "duration_min=$DURATION_MIN" \
    --field "ticket=${TICKET:-none}" 2>/dev/null || true
fi

cat >&2 <<DONE

escape-hatch: ENGAGED
  bypass:       $BYPASS
  expires:      $expires (in ${DURATION_MIN} minutes)
  audit entry:  $(echo "$entry" | node -e 'try { process.stdout.write(JSON.parse(require("fs").readFileSync(0,"utf8")).entry_sha256.slice(0,12)); } catch {}')

Next CL after the fire MUST cite this audit entry in its commit
body. The next maintainer's first action should be:

  cat audit/escape-hatch-log.jsonl | tail -5

To revoke before expiry:
  rm -f $ENV_FILE
DONE
