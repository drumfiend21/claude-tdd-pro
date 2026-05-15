#!/usr/bin/env bash
# /migrate — O-3 plugin lifecycle migration runner per §16:
# "migrations/<from>-to-<to>.sh per-version (preserve user state)".
# Records completion in .claude-tdd-pro/lock.json migrations_applied.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
FROM=""; TO=""; DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: migrate.sh --from <semver> --to <semver> [--dry-run]"; exit 0 ;;
    *) echo "migrate: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$FROM" || -z "$TO" ]] && { echo "migrate: --from and --to required" >&2; exit 2; }

SCRIPT_NAME="${FROM}-to-${TO}.sh"
SCRIPT="$PLUGIN_ROOT/migrations/$SCRIPT_NAME"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "migrate: dry-run; would invoke migrations/${SCRIPT_NAME} (no writes)" >&2
  exit 0
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "migrate: migration script not found: migrations/${SCRIPT_NAME}" >&2
  exit 2
fi

bash "$SCRIPT" || { echo "migrate: migration script failed" >&2; exit 1; }

LOCK=".claude-tdd-pro/lock.json"
if [[ -f "$LOCK" ]]; then
  FROM="$FROM" TO="$TO" LOCK="$LOCK" node -e '
    const fs = require("fs");
    const p = process.env.LOCK;
    const j = JSON.parse(fs.readFileSync(p, "utf8"));
    j.migrations_applied = j.migrations_applied || [];
    j.migrations_applied.push({ from: process.env.FROM, to: process.env.TO, ts: new Date().toISOString() });
    fs.writeFileSync(p, JSON.stringify(j) + "\n");
  '
fi
echo "migrate: applied $FROM -> $TO" >&2
