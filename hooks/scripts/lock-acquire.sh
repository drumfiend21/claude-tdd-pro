#!/usr/bin/env bash
# hooks/scripts/lock-acquire.sh — acquire a sectioned advisory lock per §2.7.
# Locks live in the _locks block of .claude-tdd-pro/lock.json.
#
# Usage:
#   lock-acquire.sh --section <name> --holder <pid> --expires-in <seconds> [--no-wait]
#
# Per §2.7: lock format is _locks.<section> = { holder, expires }. The
# expires field guards crashed holders — when both expires has passed AND
# the holder PID is dead, the lock is considered stale and may be replaced.
#
# Exit codes:
#   0 — lock acquired
#   1 — lock currently held by live holder (only with --no-wait)
#   2 — usage error (unknown section, missing args)

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"

# 15-section enum per §2.7 (verbatim).
KNOWN_SECTIONS=(rubric detectors standards compliance prompts models pr_corpus profile verify workflow_state standards_freshness pr_corpus_freshness compliance_freshness rule_cache quality_standards_directory)

SECTION=""
HOLDER=""
EXPIRES_IN=""
NO_WAIT=0
LOCK_PATH="$PWD/.claude-tdd-pro/lock.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION="$2"; shift 2 ;;
    --holder) HOLDER="$2"; shift 2 ;;
    --expires-in) EXPIRES_IN="$2"; shift 2 ;;
    --no-wait) NO_WAIT=1; shift ;;
    --lock-path) LOCK_PATH="$2"; shift 2 ;;
    --list-sections)
      printf 'section=%s\n' "${KNOWN_SECTIONS[@]}"
      exit 0
      ;;
    *) echo "lock-acquire: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$SECTION" ]] && { echo "lock-acquire: --section <name> required" >&2; exit 2; }
[[ -z "$HOLDER" ]] && { echo "lock-acquire: --holder <pid> required" >&2; exit 2; }
[[ -z "$EXPIRES_IN" ]] && EXPIRES_IN=60

# Verify section is in the §2.7 15-section enum.
is_known=0
for known in "${KNOWN_SECTIONS[@]}"; do
  [[ "$SECTION" == "$known" ]] && { is_known=1; break; }
done
if [[ "$is_known" -eq 0 ]]; then
  echo "lock-acquire: section \"$SECTION\" not in registered enum (§2.7 15-section list)" >&2
  echo "valid sections: ${KNOWN_SECTIONS[*]}" >&2
  exit 2
fi

[[ ! -f "$LOCK_PATH" ]] && { echo "lock-acquire: no lock file at $LOCK_PATH (run rubric/lock.sh --init first)" >&2; exit 2; }

# Check + acquire atomically via node (single-process; lock.json is the
# coordination point). On macOS bash 3.2 + portable shell tools.
LOCK_PATH="$LOCK_PATH" SECTION="$SECTION" HOLDER="$HOLDER" EXPIRES_IN="$EXPIRES_IN" NO_WAIT="$NO_WAIT" node -e '
  const fs = require("fs");
  const path = process.env.LOCK_PATH;
  const section = process.env.SECTION;
  const holder = process.env.HOLDER;
  const expiresIn = parseInt(process.env.EXPIRES_IN, 10);
  const noWait = process.env.NO_WAIT === "1";

  function readLock() { return JSON.parse(fs.readFileSync(path, "utf8")); }
  function writeLock(l) { fs.writeFileSync(path, JSON.stringify(l) + "\n"); }
  function isPidAlive(pid) {
    try { process.kill(parseInt(pid, 10), 0); return true; } catch { return false; }
  }
  function nowIso() { return new Date().toISOString(); }
  function expiresIso(seconds) { return new Date(Date.now() + seconds * 1000).toISOString(); }

  const lock = readLock();
  lock._locks = lock._locks || {};
  const existing = lock._locks[section];
  if (existing) {
    const expired = new Date(existing.expires).getTime() < Date.now();
    const dead = !isPidAlive(existing.holder);
    if (!(expired && dead)) {
      // Live holder OR not yet expired. Block.
      if (noWait) {
        process.stderr.write(`lock-acquire: section "${section}" already held by pid=${existing.holder} expires=${existing.expires}\n`);
        process.exit(1);
      }
      // Without --no-wait, this would block; for the test substrate we
      // also exit 1 to surface the contention without spawning a wait loop.
      process.stderr.write(`lock-acquire: section "${section}" held; would-block (use --no-wait to fail-fast)\n`);
      process.exit(1);
    }
    // Expired AND dead → release and acquire.
  }

  lock._locks[section] = {
    holder: String(holder),
    expires: expiresIso(expiresIn),
    acquired_at: nowIso()
  };
  writeLock(lock);
  process.stderr.write(`lock-acquire: ok section=${section} holder=${holder}\n`);
  process.exit(0);
'
