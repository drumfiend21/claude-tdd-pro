#!/usr/bin/env bash
# W-9 PostToolUse trigger: should the ui-regression-pinner subagent fire?
# Fires when commit diff touches any of src/components/**, app/**, pages/**,
# src/routes/**.
set -uo pipefail
ROOT=""; DIFF_STUB=""; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --diff-stub) DIFF_STUB="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) shift ;;
  esac
done
TOUCHED=$(echo "$DIFF_STUB" | sed -E 's/touched=//')
case "$TOUCHED" in
  src/components/*|app/*|pages/*|src/routes/*)
    echo "ui-regression-pinner: pinner_fires=true matched_path=$TOUCHED root=$ROOT" >&2
    ;;
  *)
    echo "ui-regression-pinner: pinner_fires=false reason=no_ui_path_touched touched=$TOUCHED" >&2
    ;;
esac
