#!/usr/bin/env bash
# L-19 freshness-status reporter for the PR-corpus daily-fresh gate.
# Reports last_fetch_at, freshness_status (fresh|stale), is_fresh boolean.
# Honors per-profile pr_corpus_freshness_window override; with --enforce
# logs failures to the C-4 merkle-chained audit log.
set -uo pipefail
SOURCE=""; NOW=""; WINDOW=""; PROFILE=""; ENFORCE=0; AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --freshness-window) WINDOW="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --enforce) ENFORCE=1; shift ;;
    --audit-log) AUDIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: freshness-status.sh --source <id> --now <iso> [--freshness-window <dur>] [--profile <yaml>] [--enforce] [--audit-log <jsonl>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$SOURCE" || -z "$NOW" ]] && { echo "freshness-status: --source and --now required" >&2; exit 2; }

if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  PROFILE_WIN=$(grep -E '^pr_corpus_freshness_window:' "$PROFILE" | sed -E 's/pr_corpus_freshness_window:[[:space:]]*//' | tr -d ' "')
  [[ -n "$PROFILE_WIN" ]] && WINDOW="$PROFILE_WIN"
fi

LAST_FILE=".claude-tdd-pro/pr-corpus/last-fetch/$SOURCE.txt"
LAST=""
[[ -f "$LAST_FILE" ]] && LAST=$(tr -d '\n' < "$LAST_FILE")

IS_FRESH="false"; STATUS="stale"
if [[ -n "$LAST" && -n "$WINDOW" ]]; then
  case "$WINDOW" in
    *h) WIN_SEC=$((${WINDOW%h} * 3600)) ;;
    *m) WIN_SEC=$((${WINDOW%m} * 60)) ;;
    *d) WIN_SEC=$((${WINDOW%d} * 86400)) ;;
    *) WIN_SEC=86400 ;;
  esac
  DIFF_SEC=$(NOW="$NOW" LAST="$LAST" node -e 'process.stdout.write(String(Math.floor((new Date(process.env.NOW) - new Date(process.env.LAST))/1000)))')
  if [[ "$DIFF_SEC" -lt "$WIN_SEC" ]]; then
    IS_FRESH="true"; STATUS="fresh"
  fi
fi

echo "freshness-status: source=$SOURCE last_fetch_at=$LAST window=$WINDOW is_fresh=$IS_FRESH freshness_status=$STATUS" >&2

if [[ "$ENFORCE" -eq 1 && "$IS_FRESH" == "false" && -n "$AUDIT" ]]; then
  mkdir -p "$(dirname "$AUDIT")"
  printf '{"event":"pr-corpus-fresh-fail","source":"%s","last_fetch_at":"%s","at":"%s","window":"%s"}\n' "$SOURCE" "$LAST" "$NOW" "$WINDOW" >> "$AUDIT"
  echo "freshness-status: enforce=true logged=true audit_log=$AUDIT" >&2
fi
