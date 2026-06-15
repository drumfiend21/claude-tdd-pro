#!/usr/bin/env bash
# examples/dog-walker-marketplace/regenerate.sh
#
# Deterministically reproduces the end-to-end "dog-walker marketplace" demonstration
# by running the plugin's REAL generative pipeline (no hand-editing). Every artifact
# under ./artifacts/ is tool output. Re-run any time to prove the demo still holds:
#
#     bash examples/dog-walker-marketplace/regenerate.sh
#     bash examples/dog-walker-marketplace/regenerate.sh --out /tmp/dw   # hermetic
#
# The pipeline (all existing commands): architect-session (S-36) -> business-translate
# (S-33/S-51/S-52/S-53) -> architect-recommend (S-34) -> optimize-options (S-46) ->
# decision-package (S-50) -> cloud-adr (S-28). Fixed --now makes output deterministic.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$HERE/../.." && pwd -P)}"
C="$ROOT/commands"
OUT="$HERE/artifacts"
NOW="2026-06-08T12:00:00Z"

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) echo "Usage: regenerate.sh [--out <dir>]" >&2; exit 0 ;;
    *) echo "regenerate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"
SESS="$OUT/_session"
rm -rf "$SESS"

# 1) The non-technical founder's answers, captured as a business profile.
cat > "$OUT/01-business-profile.json" <<'JSON'
{
  "complete": true,
  "vision": "a marketplace app connecting dog owners with trusted local dog walkers",
  "answers": {
    "workload": "a marketplace app connecting dog owners with trusted local dog walkers",
    "motivation": "revenue",
    "criticality": "mission-critical",
    "availability_tolerance": "minutes",
    "data_loss_tolerance": "minutes",
    "data_sensitivity": "confidential",
    "compliance_regime": "none",
    "scale": "large",
    "budget_posture": "balanced",
    "data_volume": "large",
    "read_write_pattern": "balanced",
    "consistency_need": "eventual",
    "communication_style": "event-driven",
    "integration_scope": "public",
    "data_cadence": "real-time"
  }
}
JSON

# 2) Drive the guided session: intake -> translate -> recommend -> explain.
bash "$C/architect-session.sh" \
  --vision "dog-walker marketplace" \
  --profile "$OUT/01-business-profile.json" \
  --out-dir "$SESS" --now "$NOW" >/dev/null

cp "$SESS/technical-requirements.json" "$OUT/02-technical-requirements.json"
cp "$SESS/architecture-options.json"   "$OUT/03-architecture-options.json"
cp "$SESS/explanation.md"              "$OUT/05-explanation.md"
cp "$SESS/session.md"                  "$OUT/06-session.md"

# 3) Score the options against the four business objectives.
bash "$C/optimize-options.sh" \
  --options "$OUT/03-architecture-options.json" \
  --profile "$OUT/01-business-profile.json" \
  --out "$OUT/04-option-scoring.json" >/dev/null

# 4) Close the vision -> implementation loop.
bash "$C/decision-package.sh" \
  --options "$OUT/03-architecture-options.json" \
  --scoring "$OUT/04-option-scoring.json" \
  --out "$OUT/07-decision-package.json" >/dev/null
# decision-package also writes a plain-language decision.md sibling; name it in-sequence.
[ -f "$OUT/decision.md" ] && mv "$OUT/decision.md" "$OUT/07b-decision-summary.md"

# 5) Record the chosen design as a MADR Architecture Decision Record.
rm -rf "$OUT/08-adr"; mkdir -p "$OUT/08-adr"
ADR_ARGS="$(bash "$C/architect-recommend.sh" \
  --requirements "$OUT/02-technical-requirements.json" \
  --profile "$OUT/01-business-profile.json" \
  --emit-adr-args opt-balanced 2>/dev/null)"
eval "bash \"$C/cloud-adr.sh\" $ADR_ARGS \
  --slug adopt-balanced-hybrid-for-the-dog-walker-marketplace \
  --seq 1 --status accepted --out-dir \"$OUT/08-adr\" --now \"$NOW\"" >/dev/null

rm -rf "$SESS"
echo "regenerated dog-walker-marketplace artifacts -> $OUT" >&2
