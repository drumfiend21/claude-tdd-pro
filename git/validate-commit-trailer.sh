#!/usr/bin/env bash
# W-4 commit-message validator. When the last commit touches an
# ADR-tracked path, require `Decision: <adr-id>` trailer in the message.
set -uo pipefail
ROOT=""; REQUIRE_PATHS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --require-decision-on-paths) REQUIRE_PATHS="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$ROOT" || ! -d "$ROOT/.git" ]] && { echo "validate-commit-trailer: --root <git repo> required" >&2; exit 2; }

MSG=$(cd "$ROOT" && git log -1 --format=%B 2>/dev/null)
CHANGED=$(cd "$ROOT" && git show --name-only --format= HEAD 2>/dev/null)

# Detect if any required path is in the changed set.
TOUCHED=0
for p in $REQUIRE_PATHS; do
  if echo "$CHANGED" | grep -qF "$p"; then TOUCHED=1; break; fi
done

if [[ "$TOUCHED" -eq 0 ]]; then
  echo "validate-commit-trailer: no_tracked_path_touched (no Decision trailer required)" >&2
  exit 0
fi

DECISION=$(echo "$MSG" | grep -oE 'Decision:[[:space:]]*[0-9]+' | head -1 | sed -E 's/Decision:[[:space:]]*//')
if [[ -z "$DECISION" ]]; then
  echo "validate-commit-trailer: missing_decision_trailer commit touches ADR-tracked path (paths=$REQUIRE_PATHS)" >&2
  exit 1
fi

echo "validate-commit-trailer: decision_trailer=$DECISION (commit touches ADR-tracked path)" >&2
