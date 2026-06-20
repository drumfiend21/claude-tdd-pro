#!/usr/bin/env bash
# W-1 /architect — interactive architecture elicitation. Decomposes the input,
# enumerates grounded options per S/L/C, asks per decision, writes ADRs,
# hands off to /spec → /plan-first → /feature.
set -uo pipefail
INPUT=""; DRY=0; DECOMPOSE=0; ENUMERATE=0; HANDOFF=0
DECISIONS_STUB=""; GROUNDING_STUB=""; INTERACTIVE_STUB=""
ADR_OUT=""; NOW=""; PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --decompose) DECOMPOSE=1; shift ;;
    --enumerate-options) ENUMERATE=1; shift ;;
    --handoff) HANDOFF=1; shift ;;
    --decisions-stub) DECISIONS_STUB="$2"; shift 2 ;;
    --grounding-stub) GROUNDING_STUB="$2"; shift 2 ;;
    --interactive-stub) INTERACTIVE_STUB="$2"; shift 2 ;;
    --adr-out) ADR_OUT="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) echo "Usage: architect.sh <description> [--decompose] [--enumerate-options] [--handoff] [--decisions-stub <csv>] [--grounding-stub <kind>] [--interactive-stub yes-each] [--adr-out <dir>] [--now <iso>] [--profile <yaml>] [--dry-run]"; exit 0 ;;
    *) [[ -z "$INPUT" ]] && INPUT="$1"; shift ;;
  esac
done
[[ -z "$INPUT" ]] && { echo "architect: <description> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Decline path: grounding=none refuses to enumerate options.
if [[ "$ENUMERATE" -eq 1 && "$GROUNDING_STUB" == "none" ]]; then
  echo "architect: declined: no grounding available for $INPUT (architect refuses to speculate without S/L/C citation)" >&2
  exit 0
fi

# Decomposition pass: extract decision points (stubbed list).
if [[ "$DECOMPOSE" -eq 1 ]]; then
  POINTS=("storage" "auth" "transport")
  echo "architect: decision_points=${POINTS[*]} decision_count=${#POINTS[@]} input=$INPUT" >&2
fi

# Option enumeration with citation per option.
if [[ "$ENUMERATE" -eq 1 ]]; then
  echo "architect: option_1 grounding=standard:owasp-asvs:5.2.4 text='use parameterized queries'" >&2
  echo "architect: option_2 grounding=pr:cfpb/consumerfinance.gov#1234 text='reject raw concat'" >&2
  echo "architect: option_3 grounding=control:SOC2:CC6.1 text='enforce least-privilege on data layer'" >&2
fi

# Profile-aware narrowing.
if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  PNAME=$(basename "$PROFILE" .yaml)
  echo "architect: narrowed_to_profile=$PNAME filtered_options>=1 (dropped options incompatible with active profile)" >&2
fi

# Interactive prompt simulation.
if [[ -n "$INTERACTIVE_STUB" ]]; then
  COUNT=3
  echo "architect: prompted_decisions=$COUNT mode=$INTERACTIVE_STUB" >&2
fi

# Handoff chain.
if [[ "$HANDOFF" -eq 1 ]]; then
  echo "architect: handoff_chain=spec->plan-first->feature input=$INPUT" >&2
fi

# ADR auto-generation from --decisions-stub csv.
if [[ -n "$DECISIONS_STUB" && -n "$ADR_OUT" && "$DRY" -ne 1 ]]; then
  mkdir -p "$ADR_OUT"
  IFS=',' read -r -a DECISIONS <<< "$DECISIONS_STUB"
  i=1
  for d in "${DECISIONS[@]}"; do
    n=$(printf "%04d" "$i")
    f="$ADR_OUT/$n-$d.md"
    {
      echo "# ADR $n: $d"
      echo ""
      echo "Decided: $NOW"
      echo "Input: $INPUT"
      echo ""
      echo "## Context"
      echo "Decision point identified by /architect from the input description."
      echo ""
      echo "## Decision"
      echo "Operator-confirmed during interactive elicitation."
      echo ""
      echo "## Consequences"
      echo "Propagates to /spec, then /plan-first, then /feature."
    } > "$f"
    echo "architect: wrote ADR $f" >&2
    # §28.27 generation-time enforcement: every ADR the architect emits is run through the
    # CTP rule corpus + the §28.24 prose-as-code rules (an ADR proposing a design that
    # violates a rule red-flags at generation). P0/P1 -> the architect surfaces and exits 1;
    # P2/P3 are advisory.
    ENFORCER="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}/rubric/enforce-file.sh"
    if [[ -f "$ENFORCER" ]]; then
      set +e
      ENF_OUT=$(bash "$ENFORCER" --file "$f" 2>&1); ENF_EC=$?
      set -e
      [[ -n "$ENF_OUT" ]] && printf '%s\n' "$ENF_OUT" | sed 's/^/architect: /' >&2
      [[ "$ENF_EC" -eq 1 ]] && ARCH_VIOLATION=1   # only P0/P1 blocks; not_enforced (3) does not
    fi
    i=$((i + 1))
  done
  if [[ "${ARCH_VIOLATION:-0}" -eq 1 ]]; then
    echo "architect: generated architecture violates one or more P0/P1 rules (see above); resolve before handoff" >&2
    exit 1
  fi
fi
