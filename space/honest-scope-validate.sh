#!/usr/bin/env bash
# Q-8 honest-scope validator: ensures README documents solo-scale self-observation caveat.
set -uo pipefail
README=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --readme) README="$2"; shift 2 ;;
    -h|--help) echo "Usage: honest-scope-validate.sh --readme <path>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$README" || ! -f "$README" ]] && { echo "honest-scope-validate: --readme <path> required" >&2; exit 2; }

if ! grep -q 'self-observation' "$README"; then
  echo "honest-scope-validate: missing self-observation caveat in $README (must reference solo-scale self-observation, not productivity science)" >&2
  exit 1
fi
echo "honest-scope-validate: ok ($README documents self-observation scope)" >&2
exit 0
