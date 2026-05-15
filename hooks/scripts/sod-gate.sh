#!/usr/bin/env bash
# sod-gate.sh — C-5 substrate. Separation-of-Duties verifier-output
# gate per architecture section 16 C-5: "SoD gate with verifier
# output schema at .claude-tdd-pro/verify/<pr-sha>.json
# (verdict: concur|diverge|abstain); hooks/scripts/sod-gate.sh."
#
# Usage:
#   --enforce                        : evaluate verifier output and gate
#   --check                          : validate verifier-output schema only
#   --emit <path> --verdict <v>      : write a verifier-output JSON
#   --pr-sha <sha>                   : the PR SHA the verdict applies to
#   --verifier-output <path>         : path to <pr-sha>.json
#   --critical-paths <file>          : globs that trigger SoD on abstain
#   --changed-files <file>           : list of files changed in the PR
#   --profile <yaml>                 : profile.yaml — toggle via require.sod_gate_on_critical_paths
#   --audit-log <path>               : append decision to JSONL audit log

set -uo pipefail

PR_SHA=""
VERIFIER_OUTPUT=""
CRITICAL_PATHS=""
CHANGED_FILES=""
PROFILE=""
AUDIT_LOG=""
ENFORCE=0
CHECK=0
EMIT=""
VERDICT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-sha) PR_SHA="$2"; shift 2 ;;
    --verifier-output) VERIFIER_OUTPUT="$2"; shift 2 ;;
    --critical-paths) CRITICAL_PATHS="$2"; shift 2 ;;
    --changed-files) CHANGED_FILES="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --enforce) ENFORCE=1; shift ;;
    --check) CHECK=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --verdict) VERDICT_ARG="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sod-gate.sh --pr-sha <sha> --verifier-output <path> [--enforce|--check|--emit <path> --verdict <v>]"
      exit 0
      ;;
    *) shift ;;
  esac
done

# Emit mode: write a verifier-output JSON at the conventional path.
if [[ -n "$EMIT" && -n "$VERDICT_ARG" ]]; then
  if [[ -z "$PR_SHA" ]]; then
    echo "sod-gate: --emit requires --pr-sha" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$EMIT")"
  printf '{"pr_sha":"%s","verdict":"%s","reviewer":"sod-gate-cli","emitted_at":"%s"}\n' "$PR_SHA" "$VERDICT_ARG" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$EMIT"
  echo "sod-gate: emitted verdict=$VERDICT_ARG for pr_sha=$PR_SHA at $EMIT" >&2
  exit 0
fi

# Profile toggle: when sod_gate_on_critical_paths is false, gate
# is disabled (always passes).
if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  if grep -qE 'sod_gate_on_critical_paths:\s*false' "$PROFILE"; then
    echo "sod-gate: gate disabled by profile (sod_gate_on_critical_paths: false)" >&2
    exit 0
  fi
fi

# Verifier output is required for --enforce / --check.
if [[ -z "$VERIFIER_OUTPUT" ]]; then
  echo "sod-gate: --verifier-output required" >&2
  exit 2
fi

if [[ ! -f "$VERIFIER_OUTPUT" ]]; then
  echo "sod-gate: verifier-output missing at $VERIFIER_OUTPUT (no verifier ran for pr_sha=$PR_SHA)" >&2
  exit 2
fi

VERIFIER_OUTPUT="$VERIFIER_OUTPUT" PR_SHA="$PR_SHA" CRITICAL_PATHS="$CRITICAL_PATHS" \
CHANGED_FILES="$CHANGED_FILES" ENFORCE="$ENFORCE" CHECK="$CHECK" \
AUDIT_LOG="$AUDIT_LOG" node -e '
const fs = require("fs");
const path = require("path");
const verifierOutput = process.env.VERIFIER_OUTPUT;
const expectedSha = process.env.PR_SHA;
const criticalPaths = process.env.CRITICAL_PATHS;
const changedFiles = process.env.CHANGED_FILES;
const enforce = process.env.ENFORCE === "1";
const check = process.env.CHECK === "1";
const auditLog = process.env.AUDIT_LOG;

let data;
try {
  data = JSON.parse(fs.readFileSync(verifierOutput, "utf8"));
} catch (e) {
  process.stderr.write(`sod-gate: verifier output invalid JSON: ${e.message}\n`);
  process.exit(2);
}

const validVerdicts = ["concur", "diverge", "abstain"];
if (!validVerdicts.includes(data.verdict)) {
  process.stderr.write(`sod-gate: verdict "${data.verdict}" must be one of [${validVerdicts.join(", ")}]\n`);
  process.exit(2);
}

if (data.pr_sha !== expectedSha) {
  process.stderr.write(`sod-gate: pr_sha mismatch — verifier output is for ${data.pr_sha} but gate invoked for ${expectedSha}\n`);
  process.exit(2);
}

if (check) {
  process.stderr.write(`sod-gate: check passed — verdict=${data.verdict} pr_sha=${data.pr_sha}\n`);
  process.exit(0);
}

if (!enforce) process.exit(0);

let outcome = "pass";
let reason = "";

if (data.verdict === "diverge") {
  outcome = "block";
  reason = `diverge verdict from ${data.reviewer || "verifier"}: ${data.reason || "no reason supplied"}`;
}

if (data.verdict === "abstain") {
  // Abstain blocks ONLY when changed files touch critical paths.
  let touchesCritical = false;
  if (criticalPaths && changedFiles && fs.existsSync(criticalPaths) && fs.existsSync(changedFiles)) {
    const patterns = fs.readFileSync(criticalPaths, "utf8").trim().split("\n").filter(Boolean);
    const files = fs.readFileSync(changedFiles, "utf8").trim().split("\n").filter(Boolean);
    for (const f of files) {
      for (const p of patterns) {
        const dirPart = p.replace(/\/\*\*\/?$/, "").replace(/\/\*\*$/, "");
        if (f.startsWith(dirPart)) { touchesCritical = true; break; }
      }
      if (touchesCritical) break;
    }
  }
  if (touchesCritical) {
    outcome = "block";
    reason = `abstain verdict on PR touching critical paths`;
  }
}

if (auditLog) {
  fs.mkdirSync(path.dirname(auditLog), { recursive: true });
  fs.appendFileSync(auditLog, JSON.stringify({
    event: "sod-gate",
    pr_sha: expectedSha,
    verdict: data.verdict,
    outcome,
    reason: reason || null,
    at: new Date().toISOString(),
  }) + "\n");
}

if (outcome === "block") {
  process.stderr.write(`sod-gate: BLOCKED — ${reason}\n`);
  process.exit(2);
}

process.stderr.write(`sod-gate: PASS — verdict=${data.verdict} pr_sha=${expectedSha}\n`);
process.exit(0);
'
