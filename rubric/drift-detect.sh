#!/usr/bin/env bash
# rubric/drift-detect.sh — F-4 drift-detection skill (substrate stub).
# Per §16 F-4: post-commit scan for // rubric: ignore, --no-verify,
# repeated bypass; tracks E-5 inline suppressions. Cross-references
# E-10 deprecations: warns when an inline suppression points at a
# deprecated rule.
#
# Usage:
#   drift-detect.sh --tree <dir> --paths <glob>
set -uo pipefail

TREE=""; PATHS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree) TREE="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    *) echo "drift-detect: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Build deprecated-rule-id list AND known-rule-id list from --tree.
DEPRECATED_IDS=()
KNOWN_IDS=()
if [[ -n "$TREE" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    while IFS= read -r id; do
      [[ -n "$id" ]] && DEPRECATED_IDS+=("$id")
    done < <(perl -ne 'while (/\bid:\s*([a-zA-Z0-9_\/-]+)[^}\n]*\bdeprecated:\s*true/g) { print "$1\n"; }' "$f" 2>/dev/null)
    while IFS= read -r id; do
      [[ -n "$id" ]] && KNOWN_IDS+=("$id")
    done < <(perl -ne 'while (/\bid:\s*([a-zA-Z0-9_\/-]+)/g) { print "$1\n"; }' "$f" 2>/dev/null)
  done < <(find "$TREE" -name "*.yaml" -type f 2>/dev/null)
fi

# Walk source paths for inline suppressions; warn when reference is
# deprecated OR unknown (not present in any tree source-file).
if [[ -n "$PATHS" ]]; then
  EXT_PATTERN=$(echo "$PATHS" | grep -oE '\*\.[a-zA-Z0-9]+$' || true)
  [[ -z "$EXT_PATTERN" ]] && EXT_PATTERN="*"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    while IFS= read -r line; do
      RULE_REF=$(echo "$line" | grep -oE 'rubric-disable[a-z-]*[[:space:]]+[a-zA-Z0-9_/-]+' | awk '{print $NF}')
      [[ -z "$RULE_REF" ]] && continue
      is_deprecated=0
      is_known=0
      for did in "${DEPRECATED_IDS[@]:-}"; do
        [[ "$RULE_REF" == "$did" ]] && is_deprecated=1
      done
      for kid in "${KNOWN_IDS[@]:-}"; do
        [[ "$RULE_REF" == "$kid" ]] && is_known=1
      done
      if [[ "$is_deprecated" -eq 1 ]]; then
        echo "drift-detect: $f references $RULE_REF (deprecated); consider /migrate-rule" >&2
      elif [[ "$is_known" -eq 0 ]]; then
        echo "drift-detect: $f references $RULE_REF (deprecated or unknown - not in tree); consider /migrate-rule" >&2
      fi
    done < "$f"
  done < <(find . -name "$EXT_PATTERN" -type f 2>/dev/null)
fi

exit 0
