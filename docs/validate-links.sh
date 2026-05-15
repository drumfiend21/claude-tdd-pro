#!/usr/bin/env bash
# docs/validate-links.sh — H-9 broken-link check.
set -uo pipefail
DIR="${1:-docs/}"
[[ ! -d "$DIR" ]] && { echo "validate-links: $DIR not a directory" >&2; exit 2; }
fail=0
while IFS= read -r f; do
  while IFS= read -r link; do
    target=$(echo "$link" | sed -E 's|.*\(([^)]+)\).*|\1|')
    [[ "$target" == http* ]] && continue
    [[ "$target" == \#* ]] && continue
    targetfile="$(dirname "$f")/$target"
    if [[ ! -f "$targetfile" ]] && [[ ! -f "${targetfile%#*}" ]]; then
      echo "broken link in $f: $target -> $targetfile" >&2
      fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" 2>/dev/null)
done < <(find "$DIR" -name "*.md" -type f 2>/dev/null)
exit $fail
