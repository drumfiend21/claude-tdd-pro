#!/usr/bin/env bash
# standards/consumption-trace.sh — S-18 generation-time consumption
# trace per §16 + §2.18 schema. Records which sources were consulted
# during a generation, with content_hash + fetched_at + freshness
# status per source.
#
# Usage:
#   consumption-trace.sh --commit-sha <sha>
#                        [--consulted <id>] [--consulted <id>] ...
#                        [--consulted-standards <id>]
#                        [--consulted-pr-corpus <id>]
#                        [--consulted-compliance <id>]
#                        [--bypassed]
#                        [--now <iso>]
#                        --emit <path>

set -uo pipefail

COMMIT_SHA=""
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EMIT=""
BYPASSED=0
CONSULTED_GENERIC=()
CONSULTED_STANDARDS=()
CONSULTED_PR=()
CONSULTED_COMPLIANCE=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit-sha) COMMIT_SHA="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --consulted) CONSULTED_GENERIC+=("$2"); shift 2 ;;
    --consulted-standards) CONSULTED_STANDARDS+=("$2"); shift 2 ;;
    --consulted-pr-corpus) CONSULTED_PR+=("$2"); shift 2 ;;
    --consulted-compliance) CONSULTED_COMPLIANCE+=("$2"); shift 2 ;;
    --bypassed) BYPASSED=1; shift ;;
    *) echo "consumption-trace: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$COMMIT_SHA" || -z "$EMIT" ]] && { echo "consumption-trace: --commit-sha and --emit required" >&2; exit 2; }
mkdir -p "$(dirname "$EMIT")"

COMMIT_SHA="$COMMIT_SHA" NOW_ISO="$NOW_ISO" EMIT="$EMIT" BYPASSED="$BYPASSED" \
GENERIC="${CONSULTED_GENERIC[*]:-}" \
STD="${CONSULTED_STANDARDS[*]:-}" \
PR="${CONSULTED_PR[*]:-}" \
COMP="${CONSULTED_COMPLIANCE[*]:-}" node -e '
  const fs = require("fs");
  const crypto = require("crypto");
  const split = (s) => (s || "").split(/\s+/).filter(Boolean);
  const generic = split(process.env.GENERIC);
  const std = split(process.env.STD).concat(generic);
  const pr = split(process.env.PR);
  const comp = split(process.env.COMP);
  const now = new Date(process.env.NOW_ISO).getTime();
  const bypassed = process.env.BYPASSED === "1";

  function sourceState(id) {
    const cachePath = `.claude-tdd-pro/standards-cache/${id}.html`;
    const fetchPath = `.claude-tdd-pro/standards-last-fetch/${id}.txt`;
    const out = {};
    if (fs.existsSync(cachePath)) {
      const buf = fs.readFileSync(cachePath);
      out.content_hash = "sha256:" + crypto.createHash("sha256").update(buf).digest("hex");
    } else {
      out.content_hash = "sha256:unknown";
    }
    if (fs.existsSync(fetchPath)) {
      const fetched = fs.readFileSync(fetchPath, "utf8").trim();
      out.fetched_at = fetched;
      const ageHours = (now - new Date(fetched).getTime()) / 3600000;
      out.freshness_at_generation = bypassed
        ? "operator-bypass"
        : (ageHours <= 24 ? "fresh-within-fetch-frequency" : "stale-warn-degraded");
    } else {
      out.fetched_at = "(unknown)";
      out.freshness_at_generation = bypassed ? "operator-bypass" : "stale-warn-degraded";
    }
    return out;
  }

  const trace = { commit: process.env.COMMIT_SHA };
  const stdState = {};
  for (const id of std) stdState[id] = sourceState(id);
  if (Object.keys(stdState).length > 0) trace.standards_state = stdState;
  if (pr.length > 0) {
    trace.pr_corpus_state = {};
    for (const id of pr) trace.pr_corpus_state[id] = sourceState(id);
  }
  if (comp.length > 0) {
    trace.compliance_state = {};
    for (const id of comp) trace.compliance_state[id] = sourceState(id);
  }

  fs.writeFileSync(process.env.EMIT, JSON.stringify(trace, null, 2));
'
