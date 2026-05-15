#!/usr/bin/env bash
# profiles/resolve.sh — R-7 substrate stub: convenience wrapper
# around profiles/active.sh that supplies a default --tree and
# remaps the resolved-profile JSON to the R-7 spec shape
# {"resolved_rules": {<id>: {severity, options, cache_key}}}.
#
# Usage:
#   resolve.sh <profile.yaml> [--emit-resolved] [--tree <dir>] [other active.sh args]

set -uo pipefail

PROFILE="$1"
shift

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
DEFAULT_TREE="$PLUGIN_ROOT/generated-code-quality-standards"

ARGS=()
HAVE_TREE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tree) HAVE_TREE=1; ARGS+=("$1" "$2"); shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

if [[ "$HAVE_TREE" -eq 0 ]]; then
  ARGS+=(--tree "$DEFAULT_TREE")
fi

TMP_ERR=$(mktemp 2>/dev/null || echo "/tmp/resolve.$$.err")
bash "$PLUGIN_ROOT/profiles/active.sh" "$PROFILE" "${ARGS[@]}" 2>"$TMP_ERR"
EXIT=$?

if [[ -s "$TMP_ERR" ]]; then
  TMP_ERR_PATH="$TMP_ERR" node -e '
    const fs = require("fs");
    const txt = fs.readFileSync(process.env.TMP_ERR_PATH, "utf8");
    const lines = txt.split("\n").filter(l => l.length > 0);
    let remapped = false;
    for (const l of lines) {
      try {
        const o = JSON.parse(l);
        if (o && o.rules && typeof o.rules === "object" && !Array.isArray(o.rules)) {
          process.stderr.write(JSON.stringify({ resolved_rules: o.rules }) + "\n");
          remapped = true;
          continue;
        }
      } catch {}
      process.stderr.write(l + "\n");
    }
  '
fi

rm -f "$TMP_ERR"
exit "$EXIT"
