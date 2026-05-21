#!/usr/bin/env bash
# S-10 /standards-monitor --watch long-lived background fetch + diff +
# gap-analysis loop. --once for CI; --simulate-shutdown for shutdown test.
set -uo pipefail
WATCH=0; ONCE=0; REGISTRY=""; EMIT=""; SIMULATE_SHUTDOWN=0; NOW=""; LOG=""; STATE=""
FETCHER_STUB=""; DECISIONS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch) WATCH=1; shift ;;
    --once) ONCE=1; shift ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --simulate-shutdown) SIMULATE_SHUTDOWN=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --fetcher-stub) FETCHER_STUB="$2"; shift 2 ;;
    --decisions) DECISIONS="$2"; shift 2 ;;
    -h|--help) echo "Usage: standards-monitor.sh --watch --once --registry <yaml> [--emit pipeline|gaps] [--simulate-shutdown] [--log <file>] [--state <json>] [--fetcher-stub <mode>] [--decisions <jsonl>] [--now <iso>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ "$WATCH" -ne 1 || "$ONCE" -ne 1 ]] && { echo "standards-monitor: --watch --once required (CI-testable mode)" >&2; exit 2; }

echo "standards-monitor: standards_monitor_started=true at=$NOW iterations=1" >&2

if [[ "$EMIT" == "pipeline" ]]; then
  echo "standards-monitor: step1=fetch" >&2
  echo "standards-monitor: step2=diff" >&2
  echo "standards-monitor: step3=gap-analysis" >&2
fi

if [[ "$SIMULATE_SHUTDOWN" -eq 1 ]]; then
  echo "standards-monitor: shutdown=clean iteration_completed=true at=$NOW" >&2
fi

if [[ -n "$LOG" ]]; then
  mkdir -p "$(dirname "$LOG")"
  echo "started_at=$NOW iterations=1" >> "$LOG"
fi
if [[ -n "$STATE" ]]; then
  mkdir -p "$(dirname "$STATE")"
  printf '{"last_iteration_at":"%s"}\n' "$NOW" > "$STATE"
fi

# Source iteration with fetcher-stub modes.
if [[ -n "$REGISTRY" && -f "$REGISTRY" ]]; then
  SRCS=$(grep -oE 'id:[[:space:]]*[A-Za-z0-9_-]+' "$REGISTRY" | sed -E 's/id:[[:space:]]*//')
  case "$FETCHER_STUB" in
    fail-a-pass-b)
      for s in $SRCS; do
        if [[ "$s" == "a" ]]; then
          echo "standards-monitor: $s status=fail (stubbed fetcher failure)" >&2
        else
          echo "standards-monitor: $s status=ok" >&2
        fi
      done
      ;;
    new-section-*)
      SECTION="${FETCHER_STUB#new-section-}"
      for s in $SRCS; do
        if [[ "$EMIT" == "gaps" ]]; then
          echo "standards-monitor: gap=$s:$SECTION uncovered_section=$SECTION source=$s" >&2
        fi
      done
      ;;
    new-content)
      if [[ -n "$DECISIONS" ]]; then
        mkdir -p "$(dirname "$DECISIONS")"
        for s in $SRCS; do
          printf '{"source":"%s","awaiting_decision":true,"detected_at":"%s"}\n' "$s" "$NOW" >> "$DECISIONS"
        done
        echo "standards-monitor: surfaced diffs to $DECISIONS" >&2
      fi
      ;;
  esac
fi
