#!/usr/bin/env bash
# L-7 /pr-corpus-update with per-source token budget (default 100k/day).
set -uo pipefail
SOURCES=()
ESTIMATED=0
CONSUMED=0
BUDGET=""
NOW=""
DRY_RUN=0
SHOW_DEFAULTS=0
BUDGET_OVERRIDE=""
UPSTREAM_STUB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCES+=("$2"); shift 2 ;;
    --estimated-tokens) ESTIMATED="$2"; shift 2 ;;
    --consumed-tokens) CONSUMED="$2"; shift 2 ;;
    --budget) BUDGET="$2"; shift 2 ;;
    --budget-override) BUDGET_OVERRIDE="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --show-defaults) SHOW_DEFAULTS=1; shift ;;
    --upstream-stub) UPSTREAM_STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: pr-corpus-update.sh --source <id> [--estimated-tokens N] [--budget <file>] [--budget-override N] [--now <iso>] [--dry-run] [--show-defaults]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DEFAULT_BUDGET=100000

if [[ "$SHOW_DEFAULTS" -eq 1 ]]; then
  echo "default_budget_per_source_per_day=$DEFAULT_BUDGET" >&2
  exit 0
fi

# Validate budget-override.
if [[ -n "$BUDGET_OVERRIDE" ]]; then
  if ! [[ "$BUDGET_OVERRIDE" =~ ^[0-9]+$ ]] || [[ "$BUDGET_OVERRIDE" -lt 0 ]]; then
    echo "pr-corpus-update: invalid_budget_override=$BUDGET_OVERRIDE (must be non-negative integer)" >&2
    exit 2
  fi
  EFFECTIVE_BUDGET="$BUDGET_OVERRIDE"
  echo "pr-corpus-update: effective_budget=$EFFECTIVE_BUDGET override=operator" >&2
fi

[[ ${#SOURCES[@]} -eq 0 ]] && { echo "pr-corpus-update: --source <id> required" >&2; exit 2; }

EFFECTIVE_BUDGET="${EFFECTIVE_BUDGET:-$DEFAULT_BUDGET}"
TODAY=${NOW%T*}
NEXT_RESET="${TODAY}T24:00:00Z"
NEXT_RESET=$(NOW="$NOW" node -e 'const d=new Date(process.env.NOW);d.setUTCHours(24,0,0,0);process.stdout.write(d.toISOString().replace(/\.\d+Z$/,"Z"))')

for src in "${SOURCES[@]}"; do
  USED=0
  RESET=false
  if [[ -n "$BUDGET" && -f "$BUDGET" ]]; then
    READ=$(BUDGET="$BUDGET" SRC="$src" TODAY="$TODAY" node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.env.BUDGET, "utf8"));
      const e = j[process.env.SRC] || {};
      const date = e.date || process.env.TODAY;
      const used = (date === process.env.TODAY) ? (e.used_today || 0) : 0;
      const reset = (date !== process.env.TODAY);
      process.stdout.write(`${used} ${reset}`);
    ')
    USED=$(echo "$READ" | awk '{print $1}')
    RESET=$(echo "$READ" | awk '{print $2}')
  fi
  REMAINING=$((EFFECTIVE_BUDGET - USED))
  ALLOWED=true
  STATUS=""
  if [[ "$RESET" == "true" ]]; then
    echo "pr-corpus-update: source=$src budget_reset=true used_today=0 remaining=$EFFECTIVE_BUDGET" >&2
    USED=0; REMAINING=$EFFECTIVE_BUDGET
  fi
  if [[ "$REMAINING" -lt "$ESTIMATED" ]]; then
    ALLOWED=false
    if [[ "$REMAINING" -le 0 ]]; then
      STATUS="budget_exhausted resets_at=$NEXT_RESET"
    else
      STATUS="skipped=token-budget"
    fi
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "pr-corpus-update: source=$src remaining=$REMAINING used_today=$USED allowed=$ALLOWED $STATUS planned_consumption=$ESTIMATED" >&2
    [[ ${#SOURCES[@]} -gt 1 ]] && echo "pr-corpus-update: $src:allowed=$ALLOWED" >&2
  fi
  # Persist consumed tokens when not dry-run.
  if [[ "$DRY_RUN" -ne 1 && "$CONSUMED" -gt 0 && -n "$BUDGET" ]]; then
    NEW_USED=$((USED + CONSUMED))
    BUDGET="$BUDGET" SRC="$src" NEW="$NEW_USED" TODAY="$TODAY" node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.env.BUDGET, "utf8"));
      j[process.env.SRC] = j[process.env.SRC] || {};
      j[process.env.SRC].used_today = parseInt(process.env.NEW, 10);
      j[process.env.SRC].date = process.env.TODAY;
      fs.writeFileSync(process.env.BUDGET, JSON.stringify(j));
    '
    echo "pr-corpus-update: source=$src consumed=$CONSUMED total_used_today=$NEW_USED" >&2
  fi
done
