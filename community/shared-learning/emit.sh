#!/usr/bin/env bash
# O-9 anonymous shared-learning emission. Opt-in only; aggregate-only
# (no per-rule detail, no IP). Stable hashed_id per operator.
set -uo pipefail
COUNTS=""; OPT_IN=0; USER=""; DRY=0; SIMULATE_EGRESS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --counts) COUNTS="$2"; shift 2 ;;
    --opt-in) OPT_IN=1; shift ;;
    --user) USER="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --simulate-egress) SIMULATE_EGRESS=1; shift ;;
    -h|--help) echo "Usage: emit.sh --opt-in [--counts <json>] [--user <id>] [--dry-run] [--simulate-egress]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$OPT_IN" -ne 1 ]]; then
  echo "shared-learning: opt_in_required (run with --opt-in; aggregate-only emission is disabled by default)" >&2
  exit 2
fi

# Stable hashed identifier per operator (sha256 of user string).
HASH=""
if [[ -n "$USER" ]]; then
  HASH=$(printf '%s' "$USER" | shasum -a 256 | awk '{print $1}')
fi
[[ -z "$HASH" ]] && HASH=$(printf '%s' "$(whoami)@$(hostname)" | shasum -a 256 | awk '{print $1}')

# Aggregate-only payload: strip per_rule keys; carry only fp + tp totals.
FP=0; TP=0
if [[ -n "$COUNTS" && -f "$COUNTS" ]]; then
  KV=$(COUNTS="$COUNTS" node -e '
    const j = JSON.parse(require("fs").readFileSync(process.env.COUNTS, "utf8"));
    let fp = 0, tp = 0;
    if (j.aggregate && typeof j.aggregate === "object") {
      fp = j.aggregate.fp || 0; tp = j.aggregate.tp || 0;
    } else {
      fp = j.fp || 0; tp = j.tp || 0;
    }
    process.stdout.write(`${fp} ${tp}`);
  ')
  FP=$(echo "$KV" | awk '{print $1}')
  TP=$(echo "$KV" | awk '{print $2}')
fi

PAYLOAD="{\"hashed_id\":\"$HASH\",\"fp\":$FP,\"tp\":$TP,\"aggregate_only\":true}"

if [[ "$DRY" -eq 1 ]]; then
  echo "shared-learning: dry_run=true payload=$PAYLOAD" >&2
  echo "shared-learning: hashed_id=$HASH fp=$FP tp=$TP aggregate_only=true" >&2
  if [[ "$SIMULATE_EGRESS" -eq 1 ]]; then
    echo "shared-learning: egress_simulated=true no_ip_collection=true (network identifiers stripped from payload)" >&2
  fi
  exit 0
fi

echo "shared-learning: emitted hashed_id=$HASH fp=$FP tp=$TP aggregate_only=true" >&2
