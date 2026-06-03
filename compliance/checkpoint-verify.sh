#!/usr/bin/env bash
# O-5 / C-4 checkpoint signature verifier. Confirms the checkpoint's
# `signature` field matches the configured signing-key stub (test
# affordance for the otherwise-cryptographic verification path).
set -uo pipefail

CHECKPOINT=""
STUB=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checkpoint) CHECKPOINT="$2"; shift 2 ;;
    --signing-stub) STUB="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: checkpoint-verify.sh --checkpoint <file> --signing-stub <expected>" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$CHECKPOINT" || ! -f "$CHECKPOINT" ]] && { echo "verify: --checkpoint <file> required" >&2; exit 2; }

SIG=$(CHECKPOINT="$CHECKPOINT" node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.env.CHECKPOINT,"utf8")).signature||""))')

if [[ "$SIG" = "$STUB" ]]; then
  echo "verify: signature_verified=true checkpoint=$(basename "$CHECKPOINT")" >&2
  exit 0
else
  echo "verify: signature_invalid checkpoint=$(basename "$CHECKPOINT") expected=$STUB got=$SIG" >&2
  exit 2
fi
