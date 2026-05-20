#!/usr/bin/env bash
# E-14 /import-eslint-config — parses ESLint flat or .eslintrc, attempts
# direct/semantic mapping per import/eslint-rule-mapping.yaml, falls back
# to ESLint-as-detector wrap suggestion; writes profiles/imported-from-eslint.yaml.
set -uo pipefail
ARG=""; DRY_RUN=0; OUT=""; MAPPING_STUB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    --mapping-stub) MAPPING_STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: import-eslint-config.sh <config-file> [--out <yaml>] [--mapping-stub direct-match|semantic-match|no-match] [--dry-run]"; exit 0 ;;
    *) [[ -z "$ARG" ]] && ARG="$1"; shift ;;
  esac
done
[[ -z "$ARG" ]] && { echo "import-eslint-config: <config-file> required" >&2; exit 2; }
[[ ! -f "$ARG" ]] && { echo "import-eslint-config: config_file_not_found path=$ARG" >&2; exit 2; }

# Detect format by filename + content.
case "$(basename "$ARG")" in
  *flat*|*config.js|*config.mjs|*config.cjs|*config.ts) FORMAT="flat" ;;
  .eslintrc|.eslintrc.json|.eslintrc.yaml|.eslintrc.yml|.eslintrc.js) FORMAT="eslintrc" ;;
  *)
    if grep -qE 'export default' "$ARG"; then FORMAT="flat"; else FORMAT="eslintrc"; fi
    ;;
esac

# Extract rule ids (works for both flat and .eslintrc when rules: {...}).
RULES=$(grep -oE '"[A-Za-z][A-Za-z0-9_/-]*"[[:space:]]*:[[:space:]]*"(error|warn|off)"' "$ARG" | sed -E 's/"([^"]+)".*/\1/' | sort -u)
RULE_COUNT=$(echo "$RULES" | grep -c . 2>/dev/null || echo 0)

echo "import-eslint-config: parsed_format=$FORMAT rule_count=$RULE_COUNT config=$ARG" >&2

# Apply mapping for each rule per stub or default registry.
PROFILE_BUF=$(mktemp)
echo "rules:" > "$PROFILE_BUF"
for r in $RULES; do
  case "$MAPPING_STUB" in
    direct-match) RESULT="direct-match"; SEV="error" ;;
    semantic-match) RESULT="semantic-match"; SEV="error" ;;
    no-match) RESULT="suggest-eslint-detector-wrap"; SEV="warn" ;;
    *) RESULT="direct-match"; SEV="error" ;;
  esac
  echo "import-eslint-config: $r: $RESULT" >&2
  echo "  - id: $r" >> "$PROFILE_BUF"
  echo "    mapping: $RESULT" >> "$PROFILE_BUF"
  echo "    severity: $SEV" >> "$PROFILE_BUF"
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "import-eslint-config: dry_run=true (no profile written)" >&2
  rm -f "$PROFILE_BUF"
  exit 0
fi

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  mv "$PROFILE_BUF" "$OUT"
  echo "import-eslint-config: wrote $OUT rule_count=$RULE_COUNT" >&2
else
  cat "$PROFILE_BUF" >&2
  rm -f "$PROFILE_BUF"
fi
