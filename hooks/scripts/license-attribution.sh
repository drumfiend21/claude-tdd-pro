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
DRY_RUN=0
EMIT=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan) SCAN_DIR="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --check-plugins) CHECK="plugins"; shift ;;
    --check-attestations) CHECK="attestations"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: license-attribution.sh [--scan <dir> --check secrets|license-headers] | --check-plugins | --check-attestations | --dry-run --out <file> | --emit json --out <file>"
      exit 0
      ;;
    *) shift ;;
  esac
done

# H-8 dry-run mode: report planned actions, do not write report files.
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "license-attribution: dry_run=true" >&2
  echo "license-attribution: planned: validate plugins (.claude-tdd-pro/plugins/registered/*/plugin.yaml)" >&2
  echo "license-attribution: planned: validate attestations (compliance/attestations/*.yaml)" >&2
  echo "license-attribution: planned: validate registry (compliance/licenses.yaml)" >&2
  exit 0
fi

# H-8 --emit json: structured per-component records from compliance/licenses.yaml.
if [[ "$EMIT" == "json" ]]; then
  [[ -z "$OUT" ]] && { echo "license-attribution: --emit json requires --out <file>" >&2; exit 2; }
  PLUGIN_ROOT_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
  REG="$PLUGIN_ROOT_DIR/compliance/licenses.yaml"
  REG="$REG" OUT="$OUT" node -e '
    const fs = require("fs");
    const records = [];
    if (fs.existsSync(process.env.REG)) {
      const body = fs.readFileSync(process.env.REG, "utf8");
      const entries = body.split(/^- /m).slice(1);
      for (const e of entries) {
        const comp = (e.match(/component:\s*(.+)/) || [])[1] || "unknown";
        const lic = (e.match(/license:\s*(.+)/) || [])[1] || "unknown";
        records.push({ component: comp.trim(), license: lic.trim() });
      }
    }
    fs.writeFileSync(process.env.OUT, JSON.stringify(records));
  '
  echo "license-attribution: emitted components to $OUT" >&2
  exit 0
fi

# H-8 --check-plugins: verify every registered plugin declares a license.
if [[ "$CHECK" == "plugins" ]]; then
  FAILED=0
  for d in .claude-tdd-pro/plugins/registered/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    f="$d/plugin.yaml"
    [[ ! -f "$f" ]] && continue
    if grep -qE '^license:' "$f"; then
      lic=$(grep -E '^license:' "$f" | head -1 | sed -E 's/license:[[:space:]]*//' | tr -d ' "')
      echo "license-attribution: plugin=$name license=$lic valid=true" >&2
    else
      echo "license-attribution: plugin=$name missing_license (plugin.yaml has no license: field)" >&2
      FAILED=1
    fi
  done
  exit $FAILED
fi

# H-8 --check-attestations: verify every attestation declares a license.
if [[ "$CHECK" == "attestations" ]]; then
  FAILED=0
  for f in compliance/attestations/*.yaml; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .yaml)
    if grep -qE '^license:' "$f"; then
      lic=$(grep -E '^license:' "$f" | head -1 | sed -E 's/license:[[:space:]]*//' | tr -d ' "')
      echo "license-attribution: attestation=$name license=$lic valid=true" >&2
    else
      echo "license-attribution: attestation=$name missing_license (attestation yaml has no license: field)" >&2
      FAILED=1
    fi
  done
  exit $FAILED
fi

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
