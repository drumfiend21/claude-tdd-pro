#!/usr/bin/env bash
# L-22 daily auto-refresh entry point. Wakes once per day, walks every
# operator-registered source, and triggers fetch.sh + sync-from-sources.sh
# so the live freshness gate finds fresh state on first-use-of-day.
set -uo pipefail
REGISTRY="${1:-.claude-tdd-pro/PR-SOURCES.yaml}"
NOW="${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

[[ ! -f "$REGISTRY" ]] && { echo "auto-refresh-daily: registry $REGISTRY not found" >&2; exit 1; }

echo "auto-refresh-daily: starting at=$NOW registry=$REGISTRY" >&2
exec bash "$SCRIPT_DIR/sync-from-sources.sh" --registry "$REGISTRY" --now "$NOW"
