#!/usr/bin/env bash
# W-4 ADR superseding-chain validator. Asserts every `supersedes: NNNN`
# references an existing ADR. --emit json --out <file> writes per-ADR records.
set -uo pipefail
ADR_DIR=""; EMIT=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --adr-dir) ADR_DIR="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$ADR_DIR" || ! -d "$ADR_DIR" ]] && { echo "validate-supersedes: --adr-dir <dir> required" >&2; exit 2; }

# Build the set of existing ADR ids from filenames matching NNNN-*.md.
EXISTING=$(ls "$ADR_DIR"/*.md 2>/dev/null | grep -v INDEX.md | sed -E 's|.*/([0-9]+)-.*\.md|\1|' | sort -u)

FAILED=0
RECORDS=()
for f in "$ADR_DIR"/*.md; do
  base=$(basename "$f" .md)
  [[ "$base" == "INDEX" ]] && continue
  adr_id=$(echo "$base" | sed -E 's|^([0-9]+)-.*|\1|')
  status=$(grep -E '^status:' "$f" | head -1 | sed -E 's/status:[[:space:]]*//' | tr -d ' "')
  status="${status:-accepted}"
  supersedes=$(grep -E '^supersedes:' "$f" | head -1 | sed -E 's/supersedes:[[:space:]]*//' | tr -d ' "')

  if [[ -n "$supersedes" ]]; then
    if ! echo "$EXISTING" | grep -qFx "$supersedes"; then
      echo "validate-supersedes: invalid_supersedes=$supersedes adr=$adr_id (no such ADR)" >&2
      FAILED=1
    fi
  fi

  RECORDS+=("{\"adr_id\":\"$adr_id\",\"status\":\"$status\",\"supersedes\":\"$supersedes\"}")
done

if [[ "$EMIT" == "json" && -n "$OUT" ]]; then
  printf '[%s]\n' "$(IFS=','; echo "${RECORDS[*]:-}")" > "$OUT"
  echo "validate-supersedes: emitted ${#RECORDS[@]} record(s) to $OUT" >&2
fi

if [[ "$FAILED" -eq 0 ]]; then
  echo "validate-supersedes: all_supersedes_valid=true adr_count=${#RECORDS[@]}" >&2
  exit 0
fi
exit 1
