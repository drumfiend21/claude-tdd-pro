#!/usr/bin/env bash
# §2.23 concurrent CL execution contract checker (W-10 gate).
#
# Two or more CLs MAY execute concurrently when ALL of:
#   (a) disjoint phase set
#   (b) disjoint workflow-state subsections per §2.15
#   (c) disjoint lock sections per §2.7
#   (d) disjoint source-folder ownership
#   (e) disjoint commit branches
#
# Reads active CL envelopes from
# `.claude-tdd-pro/active-sessions/<session_id>.json` (one envelope per
# running CL); the candidate envelope is supplied via --candidate.
#
# Exit codes:
#   0  candidate disjoint with all active CLs (accept)
#   1  candidate overlaps an active CL (reject; offending resource printed)
#   2  usage error
#
# Concurrency is opt-in. When userConfig.allow_concurrent_cls is false
# (default), a non-empty active-sessions dir is treated as "sequential
# default" and the gate refuses the second CL with that explanation.
set -uo pipefail

SESSIONS_DIR=""
CANDIDATE=""
ALLOW_CONCURRENT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sessions-dir) SESSIONS_DIR="$2"; shift 2 ;;
    --candidate) CANDIDATE="$2"; shift 2 ;;
    --allow-concurrent) ALLOW_CONCURRENT=1; shift ;;
    -h|--help)
      echo "Usage: concurrent-cl-gate.sh --sessions-dir <dir> --candidate <envelope.json> [--allow-concurrent]" >&2
      exit 0
      ;;
    *) echo "concurrent-cl-gate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$SESSIONS_DIR" ]] && { echo "concurrent-cl-gate: --sessions-dir required" >&2; exit 2; }
[[ -z "$CANDIDATE" ]] && { echo "concurrent-cl-gate: --candidate required" >&2; exit 2; }
[[ ! -f "$CANDIDATE" ]] && { echo "concurrent-cl-gate: candidate not found: $CANDIDATE" >&2; exit 2; }

# Empty / missing sessions dir = no concurrent CLs = always accept.
if [[ ! -d "$SESSIONS_DIR" ]] || [[ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]]; then
  echo "concurrent-cl-gate: accept reason=no_active_sessions" >&2
  exit 0
fi

SESSIONS_DIR="$SESSIONS_DIR" CANDIDATE="$CANDIDATE" ALLOW_CONCURRENT="$ALLOW_CONCURRENT" \
node -e '
  const fs = require("fs");
  const path = require("path");
  const cand = JSON.parse(fs.readFileSync(process.env.CANDIDATE, "utf8"));
  const allow = process.env.ALLOW_CONCURRENT === "1";
  const dir = process.env.SESSIONS_DIR;
  const files = fs.readdirSync(dir).filter(f => f.endsWith(".json"));

  if (!allow && files.length > 0) {
    process.stderr.write(`concurrent-cl-gate: reject reason=sequential_default offending_resource=active_sessions count=${files.length}\n`);
    process.exit(1);
  }

  const overlaps = (a, b, key) => {
    const av = a[key] || [];
    const bv = b[key] || [];
    const aa = Array.isArray(av) ? av : [av];
    const bb = Array.isArray(bv) ? bv : [bv];
    for (const x of aa) if (bb.includes(x)) return x;
    return null;
  };

  const dimensions = [
    ["a", "phases", "phase"],
    ["b", "state_subsections", "state_subsection"],
    ["c", "lock_sections", "lock_section"],
    ["d", "source_folders", "source_folder"],
    ["e", "branch", "branch"]
  ];

  for (const f of files) {
    const active = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
    for (const [letter, key, resource] of dimensions) {
      const ov = overlaps(cand, active, key);
      if (ov !== null) {
        process.stderr.write(`concurrent-cl-gate: reject reason=overlap_${letter} offending_resource=${resource}=${ov} holding_session=${active.session_id}\n`);
        process.exit(1);
      }
    }
  }

  process.stderr.write(`concurrent-cl-gate: accept reason=disjoint_with_${files.length}_active_sessions\n`);
  process.exit(0);
'
