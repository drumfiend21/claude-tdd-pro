#!/usr/bin/env bash
# List every shipped rubric detector for discoverability.
set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
DETECTORS_DIR="$PLUGIN_ROOT/rubric/detectors"
[[ ! -d "$DETECTORS_DIR" ]] && { echo "list-detectors: detectors dir missing at $DETECTORS_DIR" >&2; exit 2; }
for f in "$DETECTORS_DIR"/*.sh; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f" .sh)
  echo "detector=$name" >&2
done
