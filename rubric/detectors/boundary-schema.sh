#!/usr/bin/env bash
# boundary-schema.sh — N-3 substrate stub. Detects request body /
# query / param access that flows into a downstream sink without a
# prior schema validation call (zod, ajv, joi, valibot). Exits 1 on
# violation.
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.

set -uo pipefail

JSON=0
PATHS=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: boundary-schema.sh --json --paths <glob> [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "boundary-schema: dry-run; would walk $PATHS" >&2
  exit 0
fi

EXPAND_BASE=""
EXPAND_PATTERN=""
EXPAND_RECURSIVE=0
case "$PATHS" in
  *"/**"*)
    EXPAND_BASE="${PATHS%%/\*\*/*}"
    [[ "$EXPAND_BASE" == "$PATHS" ]] && EXPAND_BASE="${PATHS%/\*\*}"
    EXPAND_PATTERN="${PATHS##*/}"
    [[ "$EXPAND_PATTERN" == "**" ]] && EXPAND_PATTERN="*"
    EXPAND_RECURSIVE=1
    ;;
  */*)
    EXPAND_BASE="${PATHS%/*}"
    EXPAND_PATTERN="${PATHS##*/}"
    ;;
  *)
    EXPAND_BASE="."
    EXPAND_PATTERN="$PATHS"
    ;;
esac

[[ -d "$EXPAND_BASE" ]] || exit 0

if [[ "$EXPAND_RECURSIVE" -eq 1 ]]; then
  FIND_DEPTH=""
else
  FIND_DEPTH="-maxdepth 1"
fi

EXIT=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  HAS_VALIDATOR=0
  if grep -qE '\b(zod|ajv|joi|valibot|yup)\b|\.parse\(|\.safeParse\(|\.validate\(' "$f" 2>/dev/null; then
    HAS_VALIDATOR=1
  fi
  while IFS=':' read -r ln content; do
    [[ -z "$content" ]] && continue
    if [[ "$HAS_VALIDATOR" -eq 1 ]]; then continue; fi
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"error","rule_id":"node/boundary-schema","file":"'"$f"'","line":'"$ln"',"finding":"boundary-schema: req.body access without prior schema validation (owasp-asvs V5.1.3)","suggested_fix":"validate the request body with a schema (zod, ajv, joi, valibot) before use"}' >&2
    else
      echo "boundary-schema: $f:$ln req.body access without schema validation" >&2
    fi
    EXIT=1
  done < <(grep -nE 'req\.(body|query|params)\.' "$f" 2>/dev/null)
done < <(find "$EXPAND_BASE" $FIND_DEPTH -type f -name "$EXPAND_PATTERN" 2>/dev/null)

exit "$EXIT"
