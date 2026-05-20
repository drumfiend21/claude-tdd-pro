#!/usr/bin/env bash
# X-4 local-LLM operation router. Cheap ops (triage, affiliation-parsing,
# issue-label-filtering) route local when available; everything else
# (including local-unavailable) falls back to the remote API.
set -uo pipefail
OP=""; AVAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --operation) OP="$2"; shift 2 ;;
    --availability-stub) AVAIL="$2"; shift 2 ;;
    -h|--help) echo "Usage: route.sh --operation <op> [--availability-stub available|unavailable]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$OP" ]] && { echo "local-llm-route: --operation <op> required" >&2; exit 2; }

case "$OP" in
  triage|affiliation-parsing|issue-label-filtering) ROUTABLE=1 ;;
  *) ROUTABLE=0 ;;
esac

if [[ "$AVAIL" == "unavailable" || "$ROUTABLE" -ne 1 ]]; then
  echo "local-llm-route: route=remote-api operation=$OP fallback=true (no local backend or operation not routable)" >&2
  exit 0
fi

echo "local-llm-route: route=local-llm operation=$OP backend=ollama" >&2
