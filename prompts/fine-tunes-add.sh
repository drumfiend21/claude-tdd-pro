#!/usr/bin/env bash
# P-7 append a fine-tune artifact entry without truncating the registry.
set -uo pipefail
REGISTRY=""; AID=""; BASE_MODEL=""; TRAINING_DATA=""; LICENSE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --artifact-id) AID="$2"; shift 2 ;;
    --base-model) BASE_MODEL="$2"; shift 2 ;;
    --training-data) TRAINING_DATA="$2"; shift 2 ;;
    --license) LICENSE="$2"; shift 2 ;;
    -h|--help) echo "Usage: fine-tunes-add.sh --registry <yaml> --artifact-id <id> --base-model <name> [--training-data <id>] [--license <spdx>]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$REGISTRY" || -z "$AID" || -z "$BASE_MODEL" ]] && { echo "fine-tunes-add: --registry --artifact-id --base-model required" >&2; exit 2; }
[[ ! -f "$REGISTRY" ]] && { echo "fine-tunes-add: registry $REGISTRY not found" >&2; exit 2; }

# Append a flow-style entry preserving existing content.
echo "  - {artifact_id: $AID, base_model: $BASE_MODEL, training_data: ${TRAINING_DATA:-unspecified}, license: ${LICENSE:-unknown}}" >> "$REGISTRY"
echo "fine-tunes-add: appended artifact_id=$AID base_model=$BASE_MODEL registry=$REGISTRY" >&2
