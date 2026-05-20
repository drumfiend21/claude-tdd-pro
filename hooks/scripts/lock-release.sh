#!/usr/bin/env bash
# H-3 release a sectioned advisory lock per §2.7.
# --owner must match the lockfile's owner= field, else reject (no override).
set -uo pipefail
SECTION=""; OWNER=""; LOCK_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --lock-dir) LOCK_DIR="$2"; shift 2 ;;
    -h|--help) echo "Usage: lock-release.sh --section <name> --owner <pid> --lock-dir <dir>"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$SECTION" || -z "$OWNER" || -z "$LOCK_DIR" ]] && { echo "lock-release: --section, --owner, --lock-dir required" >&2; exit 2; }

LOCK_FILE="$LOCK_DIR/$SECTION.lock"
if [[ ! -f "$LOCK_FILE" ]]; then
  echo "lock-release: no_lock section=$SECTION (lockfile $LOCK_FILE not found)" >&2
  exit 1
fi

CURRENT=$(grep -E '^owner=' "$LOCK_FILE" | head -1 | sed -E 's/owner=//')
if [[ "$CURRENT" != "$OWNER" ]]; then
  echo "lock-release: owner_mismatch section=$SECTION current_owner=$CURRENT requested=$OWNER (lock NOT released; refuse cross-owner override)" >&2
  exit 1
fi

rm -f "$LOCK_FILE"
echo "lock-release: released section=$SECTION owner=$OWNER" >&2
