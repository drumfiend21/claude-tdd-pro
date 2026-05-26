#!/usr/bin/env bash
# /cl-status — W-10 companion command per §16:
#   "Companion command `/cl-status [--format=<text|json|tui>]` lists
#    running CLs and their held resources."
#
# Reads .claude-tdd-pro/active-sessions/<session_id>.json envelopes
# and emits each session's session_id + held resources (phases,
# lock_sections, state_subsections, source_folders, branch).
#
# Usage:
#   cl-status.sh [--format=<text|json|tui>] [--sessions-dir <dir>]
#
# Exit codes:
#   0  status emitted
#   2  usage error
set -uo pipefail

FORMAT="text"
SESSIONS_DIR="${CLAUDE_PLUGIN_ROOT:-.}/.claude-tdd-pro/active-sessions"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format=*) FORMAT="${1#--format=}"; shift ;;
    --format) FORMAT="$2"; shift 2 ;;
    --sessions-dir) SESSIONS_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: cl-status.sh [--format=<text|json|tui>] [--sessions-dir <dir>]" >&2
      exit 0
      ;;
    *) echo "cl-status: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$FORMAT" in text|json|tui) ;; *) echo "cl-status: invalid --format: $FORMAT" >&2; exit 2 ;; esac

if [[ ! -d "$SESSIONS_DIR" ]] || [[ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
  case "$FORMAT" in
    json) echo "[]" ;;
    *)    echo "cl-status: no_active_sessions" >&2 ;;
  esac
  exit 0
fi

SESSIONS_DIR="$SESSIONS_DIR" FORMAT="$FORMAT" node -e '
  (() => {
    const fs = require("fs");
    const path = require("path");
    const dir = process.env.SESSIONS_DIR;
    const fmt = process.env.FORMAT;
    const envelopes = fs.readdirSync(dir).filter(f => f.endsWith(".json"))
      .map(f => JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")));
    if (fmt === "json") {
      process.stdout.write(JSON.stringify(envelopes));
      return;
    }
    for (const e of envelopes) {
      const lines = [
        `session_id=${e.session_id || "?"}`,
        `branch=${e.branch || "?"}`,
        `phases=${(e.phases || []).join(",")}`,
        `lock_sections=${(e.lock_sections || []).join(",")}`,
        `source_folders=${(e.source_folders || []).join(",")}`,
      ];
      if (fmt === "tui") {
        process.stderr.write(`[cl-status] ${lines.join(" | ")}\n`);
      } else {
        process.stderr.write(`cl-status: ${lines.join(" ")}\n`);
      }
    }
  })();
'
exit 0
