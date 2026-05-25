#!/usr/bin/env bash
# O-4 multi-machine sync — push the canonical synced contents to the
# architecture-named `tdd-pro-sync` branch. Branch name is fixed by §13 O-4
# and is NOT operator-configurable. `--dry-run` reports what would happen
# without mutating any ref.
set -uo pipefail

ROOT=""
DRY_RUN=0
BRANCH="tdd-pro-sync"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: push.sh --root <repo-dir> [--dry-run]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$ROOT" || ! -d "$ROOT" ]] && { echo "sync-push: --root <repo-dir> required" >&2; exit 2; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "sync-push: dry_run=true branch=$BRANCH root=$ROOT" >&2
  exit 0
fi

(cd "$ROOT" && git push -u origin "HEAD:refs/heads/$BRANCH") >&2
