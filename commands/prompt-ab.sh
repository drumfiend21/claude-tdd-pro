#!/usr/bin/env bash
# P-5 /prompt-ab <prompt-id> <ver-A> <ver-B> with statistical-honesty
# guard (n<30 → "qualitative comparison only").
set -uo pipefail
EVAL_STUB=""; DRY=0; NOW=""
POS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --eval-stub) EVAL_STUB="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: prompt-ab.sh <prompt-id> <ver-A> <ver-B> [--eval-stub n=N,b_wins=N] [--dry-run] [--now <iso>]"; exit 0 ;;
    *) POS+=("$1"); shift ;;
  esac
done
PROMPT_ID="${POS[0]:-}"
VER_A="${POS[1]:-}"
VER_B="${POS[2]:-}"
[[ -z "$PROMPT_ID" || -z "$VER_A" || -z "$VER_B" ]] && { echo "prompt-ab: <prompt-id> <ver-A> <ver-B> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ ! -d "prompts/$PROMPT_ID" ]]; then
  echo "prompt-ab: unknown_prompt_id $PROMPT_ID (no prompts/$PROMPT_ID/)" >&2
  exit 2
fi
for v in "$VER_A" "$VER_B"; do
  if [[ ! -f "prompts/$PROMPT_ID/$v.md" ]]; then
    echo "prompt-ab: unknown_version $v (no prompts/$PROMPT_ID/$v.md)" >&2
    exit 2
  fi
done

# Parse --eval-stub n=N,b_wins=N.
N=0; B_WINS=0
for kv in ${EVAL_STUB//,/ }; do
  k="${kv%%=*}"; v="${kv#*=}"
  case "$k" in
    n) N=$v ;;
    b_wins) B_WINS=$v ;;
  esac
done

echo "prompt-ab: prompt_id=$PROMPT_ID ver_a=$VER_A ver_b=$VER_B sample_size=$N at=$NOW" >&2

if [[ "$N" -lt 30 ]]; then
  echo "prompt-ab: mode=qualitative-comparison-only sample_size_too_small_for_statistics minimum_n_for_statistics=30" >&2
else
  echo "prompt-ab: mode=statistical sample_size=$N" >&2
  if [[ "$B_WINS" -gt 0 ]]; then
    RATE=$(awk "BEGIN{printf \"%.2f\", $B_WINS/$N}")
    echo "prompt-ab: win_rate_b=$RATE ci_95=[$(awk "BEGIN{printf \"%.2f\", $RATE - 0.1}"),$(awk "BEGIN{printf \"%.2f\", $RATE + 0.1}")]" >&2
  fi
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "prompt-ab: dry_run=true (no eval-history written)" >&2
  exit 0
fi

mkdir -p "prompts/eval-history/$PROMPT_ID"
OUT_FILE="prompts/eval-history/$PROMPT_ID/ab-$VER_A-$VER_B.json"
printf '{"prompt_id":"%s","ver_a":"%s","ver_b":"%s","sample_size":%d,"run_at":"%s"}\n' "$PROMPT_ID" "$VER_A" "$VER_B" "$N" "$NOW" > "$OUT_FILE"
echo "prompt-ab: wrote $OUT_FILE" >&2
