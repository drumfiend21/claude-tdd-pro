#!/usr/bin/env bash
# E-11 RuleTester-equivalent test framework.
#
# Architecture §16 E-11: "RuleTester-equivalent test framework:
# `tests/<rule-id>/{valid,invalid}/<case>.{ts,json}`;
# `bash rubric/test-rule.sh <rule-id>` and `--all`; H-11 CI gate."
#
# Walks `rubric/tests/<rule-id>/{valid,invalid}/<case>.{ts,json}` and
# dispatches each case to the rule's detector (per §2.2 contract).
# Valid cases pass when the detector exits 0 (no findings); invalid
# cases pass when the detector exits non-zero (at least one finding).
#
# Usage:
#   test-rule.sh <rule-id>            run one rule's test cases
#   test-rule.sh --all                run every rule under tests-dir
#   test-rule.sh --tests-dir <dir>    override default rubric/tests
#   test-rule.sh --detector <path>    override the auto-resolved
#                                     rubric/detectors/<rule-id>.sh
#
# Exit codes:
#   0 — all cases pass
#   1 — at least one case fails (H-11 CI gate)
#   2 — usage error
set -uo pipefail

RULE=""
ALL=0
TESTS_DIR="${CLAUDE_PLUGIN_ROOT:-.}/rubric/tests"
DETECTOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=1; shift ;;
    --tests-dir) TESTS_DIR="$2"; shift 2 ;;
    --detector) DETECTOR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: test-rule.sh (<rule-id> | --all) [--tests-dir <dir>] [--detector <path>]" >&2
      exit 0
      ;;
    *) [[ -z "$RULE" && "$ALL" -eq 0 ]] && RULE="$1"; shift ;;
  esac
done

[[ "$ALL" -eq 0 && -z "$RULE" ]] && { echo "test-rule: <rule-id> or --all required" >&2; exit 2; }
[[ ! -d "$TESTS_DIR" ]] && { echo "test-rule: tests dir not found: $TESTS_DIR" >&2; exit 2; }

TOTAL_PASS=0
TOTAL_FAIL=0

run_rule() {
  local rid="$1"
  local tdir="$TESTS_DIR/$rid"
  local detector="${DETECTOR:-${CLAUDE_PLUGIN_ROOT:-.}/rubric/detectors/$rid.sh}"
  [[ ! -d "$tdir" ]] && { echo "test-rule: skip rule=$rid (no test dir)" >&2; return 0; }
  [[ ! -x "$detector" && ! -f "$detector" ]] && { echo "test-rule: skip rule=$rid (no detector at $detector)" >&2; return 0; }

  local pass=0
  local fail=0

  for case_file in "$tdir"/valid/*.ts "$tdir"/valid/*.json; do
    [[ -f "$case_file" ]] || continue
    if bash "$detector" --in "$case_file" >/dev/null 2>&1; then
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
      echo "test-rule: FAIL rule=$rid case=valid/$(basename "$case_file") (detector fired on valid case)" >&2
    fi
  done

  for case_file in "$tdir"/invalid/*.ts "$tdir"/invalid/*.json; do
    [[ -f "$case_file" ]] || continue
    if bash "$detector" --in "$case_file" >/dev/null 2>&1; then
      fail=$((fail + 1))
      echo "test-rule: FAIL rule=$rid case=invalid/$(basename "$case_file") (detector did not fire on invalid case)" >&2
    else
      pass=$((pass + 1))
    fi
  done

  echo "test-rule: rule=$rid pass=$pass fail=$fail" >&2
  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
}

if [[ "$ALL" -eq 1 ]]; then
  for d in "$TESTS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    rid=$(basename "$d")
    run_rule "$rid"
  done
else
  run_rule "$RULE"
fi

echo "test-rule: total pass=$TOTAL_PASS fail=$TOTAL_FAIL" >&2
[[ "$TOTAL_FAIL" -eq 0 ]] && exit 0 || exit 1
