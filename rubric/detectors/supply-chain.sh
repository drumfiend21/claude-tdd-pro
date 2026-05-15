#!/usr/bin/env bash
# supply-chain.sh — N-3 substrate stub. Verifies that every dependency
# in package.json carries SLSA build provenance attestation; exits 1
# when one or more deps lack it.
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.
# Plus --check {slsa|attestation} option for verification mode.

set -uo pipefail

JSON=0
PATHS=""
CHECK=""
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --paths) PATHS="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: supply-chain.sh --json --paths <dir> --check slsa [--dry-run]"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ "$DRY" -eq 1 ]]; then
  echo "supply-chain: dry-run; would walk $PATHS check=$CHECK" >&2
  exit 0
fi

[[ -z "$PATHS" ]] && { echo "supply-chain: --paths required" >&2; exit 2; }
TARGET_DIR="${PATHS%/}"
PKG="$TARGET_DIR/package.json"

if [[ ! -f "$PKG" ]]; then
  echo "supply-chain: no package.json at $TARGET_DIR" >&2
  exit 0
fi

ATTESTATION="$TARGET_DIR/slsa-attestations.json"
if [[ "$CHECK" == "slsa" ]]; then
  if [[ ! -f "$ATTESTATION" ]]; then
    if [[ "$JSON" -eq 1 ]]; then
      echo '{"severity":"error","rule_id":"node/supply-chain","file":"'"$PKG"'","line":0,"finding":"supply-chain: dependencies lack slsa build provenance attestation (slsa-attestations.json missing)","suggested_fix":"run npm-attestation generation step in CI to produce slsa-attestations.json"}' >&2
    else
      echo "supply-chain: $PKG: dependencies lack slsa build provenance" >&2
    fi
    exit 1
  fi
fi

exit 0
