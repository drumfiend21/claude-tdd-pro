#!/usr/bin/env bash
# L-13 /pr-corpus-decisions operator command. Delegates to list-decisions.sh
# so the same listing logic is shared with audit tooling.
set -uo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
exec bash "$SCRIPT_DIR/../pr-corpus/list-decisions.sh" "$@"
