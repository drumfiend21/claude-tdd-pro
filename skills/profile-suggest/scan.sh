#!/usr/bin/env bash
# Q-9 first-session repo scan + profile suggestion.
set -uo pipefail
ROOT=""; STATE=""; DECLINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --decline) DECLINE=1; shift ;;
    -h|--help) echo "Usage: scan.sh --root <repo> [--state <path>] [--decline]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$ROOT" ]] && { echo "scan: --root <dir> required" >&2; exit 2; }

# Persisted-state guard.
if [[ -n "$STATE" && -f "$STATE" ]]; then
  declined=$(node -e "try{const j=JSON.parse(require('fs').readFileSync('$STATE','utf8'));process.stdout.write(j.declined?'true':'false')}catch(e){process.stdout.write('false')}")
  if [[ "$declined" == "true" ]]; then
    echo "profile-suggest: declined=true (no_prompt — user previously declined the suggestion)" >&2
    exit 0
  fi
  echo "profile-suggest: already_ran=true (skipped — first-session-only mode)" >&2
  exit 0
fi

# Decline flag: persist and exit.
if [[ "$DECLINE" -eq 1 ]]; then
  [[ -z "$STATE" ]] && { echo "scan: --decline requires --state" >&2; exit 2; }
  mkdir -p "$(dirname "$STATE")"
  printf '{"declined":true,"at":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE"
  echo "profile-suggest: declined recorded to $STATE" >&2
  exit 0
fi

# Detect signals.
SIGNALS=()
STACK=""
[[ -f "$ROOT/package.json" ]] && { STACK="javascript"; SIGNALS+=("stack=javascript"); }
[[ -f "$ROOT/requirements.txt" || -f "$ROOT/pyproject.toml" ]] && { STACK="${STACK:-python}"; SIGNALS+=("stack=python"); }
[[ -f "$ROOT/Cargo.toml" ]] && { STACK="${STACK:-rust}"; SIGNALS+=("stack=rust"); }

COMPLIANCE_PRESENT=false
if [[ -d "$ROOT/compliance" ]] && find "$ROOT/compliance" -type f -name "*.yaml" 2>/dev/null | grep -q .; then
  COMPLIANCE_PRESENT=true
  SIGNALS+=("compliance=present")
fi

FINANCIAL=false
README="$ROOT/README.md"
if [[ -f "$README" ]] && grep -qiE "PCI|ledger|transaction|payment|fintech" "$README"; then
  FINANCIAL=true
  SIGNALS+=("financial_vocab=detected")
fi

GOVERNMENT=false
GOVT_KEYWORDS=""
if [[ -f "$README" ]]; then
  for kw in fedramp fisma nist-800-53; do
    if grep -qiE "$kw" "$README"; then
      GOVERNMENT=true
      GOVT_KEYWORDS="$GOVT_KEYWORDS,$kw"
    fi
  done
fi
if [[ "$GOVERNMENT" == "true" ]]; then
  SIGNALS+=("government=detected${GOVT_KEYWORDS}")
fi

# Tier selection (highest tier wins).
SUGGESTED="baseline"
if [[ "$GOVERNMENT" == "true" || "$FINANCIAL" == "true" ]]; then
  SUGGESTED="high-risk"
elif [[ "$COMPLIANCE_PRESENT" == "true" ]]; then
  SUGGESTED="regulated"
elif [[ -n "$STACK" ]]; then
  SUGGESTED="strict"
fi

echo "profile-suggest: suggested_profile=$SUGGESTED signals=${#SIGNALS[@]} ${SIGNALS[*]:-}" >&2

# Persist accepted state on first run.
if [[ -n "$STATE" ]]; then
  mkdir -p "$(dirname "$STATE")"
  printf '{"declined":false,"suggested":"%s","at":"%s"}\n' "$SUGGESTED" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE"
fi
