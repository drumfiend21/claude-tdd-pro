#!/usr/bin/env bash
# license-attribution.sh — substrate stub: scans a directory for
# attribution and secret-presence flags. Used by R-4 templates spec
# to verify shipped templates carry no secrets.
#
# Usage:
#   license-attribution.sh --scan <dir> --check secrets
#   license-attribution.sh --scan <dir> --check license-headers

set -uo pipefail

SCAN_DIR=""
CHECK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan) SCAN_DIR="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: license-attribution.sh --scan <dir> --check secrets|license-headers"
      exit 0
      ;;
    *) shift ;;
  esac
done

if [[ -z "$SCAN_DIR" || -z "$CHECK" ]]; then
  echo "license-attribution: --scan and --check are required" >&2
  exit 2
fi

if [[ ! -d "$SCAN_DIR" ]]; then
  echo "license-attribution: scan dir does not exist: $SCAN_DIR" >&2
  exit 2
fi

case "$CHECK" in
  secrets)
    SECRET_PATTERN='(AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]+|ghp_[0-9a-zA-Z]{36}|xox[baprs]-[0-9a-zA-Z-]+|-----BEGIN.*PRIVATE KEY-----|password\s*[:=]\s*["'"'"'][^"'"'"']{6,})'
    HITS=$(find "$SCAN_DIR" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.env" \) -print0 2>/dev/null \
      | xargs -0 grep -lE "$SECRET_PATTERN" 2>/dev/null || true)
    if [[ -z "$HITS" ]]; then
      echo "license-attribution: no secrets found (0 findings) in $SCAN_DIR" >&2
      exit 0
    else
      echo "license-attribution: secrets found:" >&2
      echo "$HITS" >&2
      exit 1
    fi
    ;;
  license-headers)
    MISSING=""
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if ! head -10 "$f" 2>/dev/null | grep -iqE 'license|copyright|spdx-license-identifier'; then
        MISSING="$MISSING $f"
      fi
    done < <(find "$SCAN_DIR" -type f \( -name "*.ts" -o -name "*.js" \) 2>/dev/null)
    if [[ -z "$MISSING" ]]; then
      echo "license-attribution: all files carry a license header (0 findings)" >&2
      exit 0
    else
      echo "license-attribution: missing license headers:$MISSING" >&2
      exit 1
    fi
    ;;
  *)
    echo "license-attribution: unknown --check value: $CHECK" >&2
    exit 2
    ;;
esac
