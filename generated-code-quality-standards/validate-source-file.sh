#!/usr/bin/env bash
# validate-source-file (architecture-named entry point per §17 G-6).
#
# Per §17 G-6 verbatim:
#   "Source-file schema per §2.21 contract;
#    generated-code-quality-standards/validate-source-file.sh."
#
# Wrapper that delegates to the substrate validator at
# rubric/detectors/validate-source-file.sh. The substrate predates the
# G-phase architecture; full path consolidation is tracked under §23.7
# substrate reconciliation.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
exec bash "$PLUGIN_ROOT/rubric/detectors/validate-source-file.sh" "$@"
