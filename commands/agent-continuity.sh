#!/usr/bin/env bash
# H-13 long-running agent harness continuity substrate per §26 v1.11.
# Writes / reads / purges continuation artifacts.
set -uo pipefail

ARTIFACT_DIR="${H13_ARTIFACT_DIR:-.claude-tdd-pro/agent-continuations}"
WORKFLOW_STATE="${H13_WORKFLOW_STATE:-.claude-tdd-pro/workflow-state.json}"

CMD=""
SESSION_ID=""
PARENT_SESSION=""
PARENT_CL=""
CURRENT_PHASE=""
CONTEXT_SUMMARY=""
NEXT_ACTION=""
NEXT_RATIONALE=""
NOW_ISO=""
COMPLETED_STEPS_FILE=""
PENDING_STEPS_FILE=""
LAST_TOOL_CALLS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) CMD="write"; shift ;;
    --read) CMD="read"; shift ;;
    --purge-stale) CMD="purge"; shift ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --parent-session-id) PARENT_SESSION="$2"; shift 2 ;;
    --parent-cl-id) PARENT_CL="$2"; shift 2 ;;
    --current-phase) CURRENT_PHASE="$2"; shift 2 ;;
    --context-summary) CONTEXT_SUMMARY="$2"; shift 2 ;;
    --next-action) NEXT_ACTION="$2"; shift 2 ;;
    --next-rationale) NEXT_RATIONALE="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --completed-steps-file) COMPLETED_STEPS_FILE="$2"; shift 2 ;;
    --pending-steps-file) PENDING_STEPS_FILE="$2"; shift 2 ;;
    --last-tool-calls-file) LAST_TOOL_CALLS_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: agent-continuity.sh (--write|--read|--purge-stale) [...flags]" >&2
      exit 0
      ;;
    *) echo "agent-continuity: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$CMD" ]] && { echo "agent-continuity: one of --write --read --purge-stale required" >&2; exit 2; }
[[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p "$ARTIFACT_DIR"

case "$CMD" in
  write)
    for f in SESSION_ID PARENT_SESSION PARENT_CL CURRENT_PHASE CONTEXT_SUMMARY NEXT_ACTION; do
      if [[ -z "${!f}" ]]; then
        echo "agent-continuity: --write requires --session-id --parent-session-id --parent-cl-id --current-phase --context-summary --next-action (missing: $f)" >&2
        exit 2
      fi
    done
    if [[ ${#CONTEXT_SUMMARY} -gt 500 ]]; then
      echo "agent-continuity: --context-summary exceeds 500 char limit (got ${#CONTEXT_SUMMARY})" >&2
      exit 2
    fi
    SESSION_ID="$SESSION_ID" PARENT_SESSION="$PARENT_SESSION" PARENT_CL="$PARENT_CL" \
    CURRENT_PHASE="$CURRENT_PHASE" CONTEXT_SUMMARY="$CONTEXT_SUMMARY" \
    NEXT_ACTION="$NEXT_ACTION" NEXT_RATIONALE="$NEXT_RATIONALE" \
    NOW_ISO="$NOW_ISO" ARTIFACT_DIR="$ARTIFACT_DIR" \
    COMPLETED_FILE="$COMPLETED_STEPS_FILE" PENDING_FILE="$PENDING_STEPS_FILE" \
    TOOLS_FILE="$LAST_TOOL_CALLS_FILE" node -e '
      const fs = require("fs");
      const path = require("path");
      function load(p, fallback) {
        if (!p || !fs.existsSync(p)) return fallback;
        try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return fallback; }
      }
      const lastTools = load(process.env.TOOLS_FILE, []).slice(-10);
      const artifact = {
        parent_session_id: process.env.PARENT_SESSION,
        parent_cl_id: process.env.PARENT_CL,
        current_phase: process.env.CURRENT_PHASE,
        completed_steps: load(process.env.COMPLETED_FILE, []),
        pending_steps: load(process.env.PENDING_FILE, []),
        context_summary: process.env.CONTEXT_SUMMARY,
        last_tool_calls: lastTools,
        next_action: { action: process.env.NEXT_ACTION, rationale: process.env.NEXT_RATIONALE || "" },
        written_at: process.env.NOW_ISO
      };
      const target = path.join(process.env.ARTIFACT_DIR, process.env.SESSION_ID + ".json");
      fs.writeFileSync(target, JSON.stringify(artifact));
      process.stderr.write(`agent-continuity: wrote ${target} parent_session_id=${artifact.parent_session_id} next_action="${artifact.next_action.action}"\n`);
    '
    ;;
  read)
    [[ -z "$SESSION_ID" ]] && { echo "agent-continuity: --read requires --session-id" >&2; exit 2; }
    TARGET="$ARTIFACT_DIR/$SESSION_ID.json"
    [[ ! -f "$TARGET" ]] && { echo "agent-continuity: no continuation artifact for session_id=$SESSION_ID" >&2; exit 2; }
    TARGET="$TARGET" WORKFLOW_STATE="$WORKFLOW_STATE" node -e '
      const fs = require("fs");
      const a = JSON.parse(fs.readFileSync(process.env.TARGET, "utf8"));
      const wsPath = process.env.WORKFLOW_STATE;
      if (fs.existsSync(wsPath)) {
        try {
          const ws = JSON.parse(fs.readFileSync(wsPath, "utf8"));
          const sessions = ws._concurrent ? ws.sessions : { [ws.session_id || "single"]: ws };
          if (!sessions[a.parent_session_id]) {
            process.stderr.write(`agent-continuity: parent_session_id=${a.parent_session_id} not active in workflow-state; refuse to resume\n`);
            process.exit(1);
          }
        } catch (e) {
          process.stderr.write(`agent-continuity: workflow-state read error: ${e.message}\n`);
        }
      }
      process.stderr.write(`agent-continuity: resume parent_session_id=${a.parent_session_id} next_action="${a.next_action.action}" completed_steps=${a.completed_steps.length} pending_steps=${a.pending_steps.length}\n`);
      process.stdout.write(JSON.stringify(a));
    '
    ;;
  purge)
    NOW_ISO="$NOW_ISO" ARTIFACT_DIR="$ARTIFACT_DIR" node -e '
      const fs = require("fs");
      const path = require("path");
      const now = new Date(process.env.NOW_ISO).getTime();
      const ttlMs = 24 * 3600 * 1000;
      const dir = process.env.ARTIFACT_DIR;
      let purged = 0;
      if (!fs.existsSync(dir)) { process.stderr.write(`agent-continuity: no artifact dir at ${dir}\n`); process.exit(0); }
      for (const f of fs.readdirSync(dir).filter(n => n.endsWith(".json"))) {
        try {
          const a = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
          const w = new Date(a.written_at).getTime();
          if (now - w > ttlMs) {
            fs.unlinkSync(path.join(dir, f));
            purged++;
            process.stderr.write(`agent-continuity: purged ${f} (age ${Math.round((now - w) / 3600000)}h > 24h)\n`);
          }
        } catch {}
      }
      process.stderr.write(`agent-continuity: purge complete purged=${purged}\n`);
    '
    ;;
esac
