#!/usr/bin/env bash
# Q-1 SPACE config defaults reporter.
set -uo pipefail
DIMENSION=""; FIELD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dimension) DIMENSION="$2"; shift 2 ;;
    --field) FIELD="$2"; shift 2 ;;
    -h|--help) echo "Usage: show-defaults.sh --dimension <d> | --field <f>"; exit 0 ;;
    *) shift ;;
  esac
done
if [[ -n "$DIMENSION" ]]; then
  case "$DIMENSION" in
    satisfaction)         echo "satisfaction=opt_in" >&2; echo "enabled=false" >&2 ;;
    performance)          echo "performance=on" >&2; echo "enabled=true" >&2 ;;
    activity)             echo "activity=opt_in" >&2; echo "enabled=false" >&2 ;;
    collaboration)        echo "collaboration=opt_in" >&2; echo "enabled=false" >&2 ;;
    efficiency_and_flow)  echo "efficiency_and_flow=on" >&2; echo "enabled=true" >&2 ;;
    *) echo "show-defaults: unknown dimension: $DIMENSION (valid: satisfaction|performance|activity|collaboration|efficiency_and_flow)" >&2; exit 2 ;;
  esac
fi
if [[ -n "$FIELD" ]]; then
  case "$FIELD" in
    retention_days) echo "retention_days=90" >&2 ;;
    share)          echo "share=never" >&2 ;;
    *) echo "show-defaults: unknown field: $FIELD" >&2; exit 2 ;;
  esac
fi
