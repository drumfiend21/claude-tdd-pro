#!/usr/bin/env bash
# W-2 /git-recommend — delegates to the git-workflow skill's recommend.sh.
set -uo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
exec bash "$SCRIPT_DIR/../skills/git-workflow/recommend.sh" "$@"
