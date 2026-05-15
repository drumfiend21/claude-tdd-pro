#!/usr/bin/env bash
# risk-classify.sh — C-8 substrate. Walks the EU AI Act use-case
# category for a given use-case and surfaces obligations.
#
# Per architecture section 16 C-8: "/risk-classify walks EU AI Act
# use-case category -> compliance/risk-classification.yaml -> surfaces
# obligations."
#
# Usage:
#   risk-classify.sh --use-case <name> --emit <path> [--dry-run]
#                    [--emit-walk <path>]

set -uo pipefail

USE_CASE=""
EMIT=""
EMIT_WALK=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --use-case) USE_CASE="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --emit-walk) EMIT_WALK="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: risk-classify.sh --use-case <name> --emit <path> [--dry-run] [--emit-walk <path>]"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -z "$USE_CASE" || -z "$EMIT" ]]; then
  echo "risk-classify: --use-case and --emit are required" >&2
  exit 2
fi

# EU AI Act categories per Annex III + Article 5.
classify_use_case() {
  case "$1" in
    social-scoring|emotion-recognition-workplace|biometric-categorisation-by-sensitive-traits|untargeted-facial-scraping)
      echo "prohibited"
      ;;
    credit-scoring|biometric-categorisation|biometric-identification|critical-infrastructure|education-scoring|employment-screening|essential-services-eligibility|law-enforcement|migration-asylum|justice-democratic-processes)
      echo "high"
      ;;
    chatbot|content-generation|deepfake-disclosure)
      echo "limited"
      ;;
    spam-filter|recommendation-no-personal-data|productivity-tooling)
      echo "minimal"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

CLASSIFICATION=$(classify_use_case "$USE_CASE")
if [[ "$CLASSIFICATION" == "unknown" ]]; then
  echo "risk-classify: unknown use-case category: $USE_CASE (consult EU AI Act Annex III / Article 5)" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "risk-classify: dry-run; would classify $USE_CASE as $CLASSIFICATION (no writes)" >&2
  exit 0
fi

mkdir -p "$(dirname "$EMIT")"

# Build obligations list per classification.
case "$CLASSIFICATION" in
  prohibited)
    OBLIGATIONS="  - prohibited-do-not-deploy"
    ;;
  high)
    OBLIGATIONS="  - human-oversight
  - data-governance
  - technical-documentation
  - record-keeping
  - transparency-to-users
  - accuracy-robustness-cybersecurity
  - conformity-assessment
  - post-market-monitoring"
    ;;
  limited)
    OBLIGATIONS="  - transparency-disclosure-of-ai-output"
    ;;
  minimal)
    OBLIGATIONS=""
    ;;
esac

{
  echo "use_case: $USE_CASE"
  echo "classification: $CLASSIFICATION"
  echo "source_framework: eu-ai-act"
  if [[ -n "$OBLIGATIONS" ]]; then
    echo "obligations:"
    echo "$OBLIGATIONS"
  else
    echo "obligations: []"
  fi
  echo "classified_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$EMIT"

if [[ -n "$EMIT_WALK" ]]; then
  mkdir -p "$(dirname "$EMIT_WALK")"
  {
    echo "EU AI Act walk for use-case=$USE_CASE"
    echo "  Article 5 (prohibited practices): checked"
    echo "  Annex III (high-risk systems): checked"
    echo "  Result: $CLASSIFICATION"
  } > "$EMIT_WALK"
fi

echo "risk-classify: classified $USE_CASE as $CLASSIFICATION (eu-ai-act); wrote $EMIT" >&2
exit 0
