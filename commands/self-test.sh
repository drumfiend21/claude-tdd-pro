#!/usr/bin/env bash
# /self-test — O-3 plugin lifecycle self-test per §16:
# "extends /doctor". Runs doctor + audit-chain + validate-all.
# Exit non-zero on any failure.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
fail=0
INCLUDE_BOOTSTRAP=0
EMIT_REPORT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-bootstrap) INCLUDE_BOOTSTRAP=1; shift ;;
    --emit-report) EMIT_REPORT="$2"; shift 2 ;;
    -h|--help) echo "Usage: self-test.sh [--include-bootstrap] [--emit-report <path>]"; exit 0 ;;
    *) shift ;;
  esac
done

echo "self-test: starting" >&2

if [[ "$INCLUDE_BOOTSTRAP" -eq 1 && -n "$EMIT_REPORT" ]]; then
  bash "$PLUGIN_ROOT/commands/init-guardrails.sh" --run-bootstrap-evals --emit-report "$EMIT_REPORT" >&2 2>&1 || fail=1
  if [[ -f "$EMIT_REPORT" ]]; then
    EMIT_REPORT="$EMIT_REPORT" node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.env.EMIT_REPORT, "utf8"));
      const wrapped = { bootstrap: j };
      fs.writeFileSync(process.env.EMIT_REPORT, JSON.stringify(wrapped, null, 2));
    '
  fi
fi

echo "doctor: invoking /doctor --check directory-layout" >&2
if [[ -d generated-code-quality-standards ]]; then
  bash "$PLUGIN_ROOT/commands/doctor.sh" --check directory-layout >&2 2>&1 || fail=1
else
  echo "doctor: skipped (no generated-code-quality-standards/ tree)" >&2
fi

echo "audit-chain: invoking compliance/audit-log.sh --verify-chain" >&2
if [[ -f .claude-tdd-pro/audit.jsonl ]]; then
  bash "$PLUGIN_ROOT/compliance/audit-log.sh" --verify-chain >&2 2>&1 || fail=1
else
  echo "audit-chain: skipped (no audit.jsonl)" >&2
fi

echo "validate-all: invoking generated-code-quality-standards/validate-all.sh" >&2
if [[ -d generated-code-quality-standards ]]; then
  bash "$PLUGIN_ROOT/generated-code-quality-standards/validate-all.sh" --root generated-code-quality-standards >&2 2>&1 || fail=1
else
  echo "validate-all: skipped (no source-folder tree)" >&2
fi

# Lock file integrity check.
if [[ -f .claude-tdd-pro/lock.json ]]; then
  if ! node -e 'JSON.parse(require("fs").readFileSync(".claude-tdd-pro/lock.json","utf8"))' 2>/dev/null; then
    echo "self-test: lock invalid (lock.json is not parseable JSON)" >&2
    fail=1
  fi
fi

if [[ "$fail" -eq 0 ]]; then
  echo "self-test: PASS" >&2
  exit 0
else
  echo "self-test: FAIL (one or more subsystems failed)" >&2
  exit 1
fi
