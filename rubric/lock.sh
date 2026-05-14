#!/usr/bin/env bash
# rubric/lock.sh — F-0 lock-contracts manager per §2.7.
#
# Subcommands:
#   --init [--profile <name>]   Initialize .claude-tdd-pro/lock.json with
#                               plugin_version, rubric_semver, _meta.sections
#                               (15 entries per §2.7), _locks ({}), and the
#                               other top-level fields. With --profile,
#                               compute and embed profile_snapshot_hash.
#   --check                     Read lock.json, verify plugin_version matches
#                               current; exit 2 with "plugin_version mismatch"
#                               on disagreement.
#   --merge --other-json <json> Merge another lock-file JSON into the local
#                               one. Per §2.7: standards_versions and
#                               pr_corpus_patterns by union; rubric/
#                               workflow_state by last-writer-wins.

set -uo pipefail

# Current installed plugin version. Subsequent CLs may move this to a
# version file; for now it lives at the lock substrate top.
CURRENT_PLUGIN_VERSION="1.9.0"
CURRENT_RUBRIC_SEMVER="1.0.0"

# 15-section enum per §2.7 (verbatim).
SECTIONS_15='["rubric","detectors","standards","compliance","prompts","models","pr_corpus","profile","verify","workflow_state","standards_freshness","pr_corpus_freshness","compliance_freshness","rule_cache","quality_standards_directory"]'

ACTION=""
PROFILE=""
OTHER_JSON=""
LOCK_PATH="$PWD/.claude-tdd-pro/lock.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init) ACTION="init"; shift ;;
    --check) ACTION="check"; shift ;;
    --merge) ACTION="merge"; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --other-json) OTHER_JSON="$2"; shift 2 ;;
    --lock-path) LOCK_PATH="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: rubric/lock.sh --init [--profile <name>] | --check | --merge --other-json <json>" >&2
      exit 0 ;;
    *) echo "lock: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$ACTION" ]] && { echo "lock: subcommand required (--init | --check | --merge)" >&2; exit 2; }

mkdir -p "$(dirname "$LOCK_PATH")"

case "$ACTION" in
  init)
    PROFILE_HASH=""
    if [[ -n "$PROFILE" ]]; then
      # Compute a stable hash of the profile name + a marker so the spec
      # can grep for "profile_snapshot_hash":"[a-f0-9]+". Real profile
      # resolution lands in subsequent CL when /doctor --explain ships.
      PROFILE_HASH=$(printf '%s\n' "profile:$PROFILE:v1" | shasum -a 256 | cut -d' ' -f1)
    fi
    node -e "
      const fs = require('fs');
      const out = {
        plugin_version: '$CURRENT_PLUGIN_VERSION',
        rubric_semver: '$CURRENT_RUBRIC_SEMVER',
        _meta: {
          schema_version: '1.9',
          sections: $SECTIONS_15
        },
        _locks: {},
        rubric: {},
        detectors: {},
        standards_versions: {},
        compliance_versions: {},
        pr_corpus_patterns: {},
        prompt_registry_hash: '',
        model_pins: {},
        profile_snapshot_hash: '$PROFILE_HASH',
        workflow_state_hash: '',
        quality_standards_directory_hash: ''
      };
      fs.writeFileSync('$LOCK_PATH', JSON.stringify(out) + '\n');
    "
    echo "lock: initialized at $LOCK_PATH" >&2
    exit 0
    ;;
  check)
    [[ ! -f "$LOCK_PATH" ]] && { echo "lock: no lock file at $LOCK_PATH" >&2; exit 1; }
    LOCK_VERSION=$(node -e "const l=JSON.parse(require('fs').readFileSync('$LOCK_PATH','utf8'));process.stdout.write(l.plugin_version||'');")
    if [[ "$LOCK_VERSION" != "$CURRENT_PLUGIN_VERSION" ]]; then
      echo "lock: plugin_version mismatch — lock has '$LOCK_VERSION', installed is '$CURRENT_PLUGIN_VERSION'; run /migrate" >&2
      exit 2
    fi
    echo "lock: plugin_version ok ($CURRENT_PLUGIN_VERSION)" >&2
    exit 0
    ;;
  merge)
    [[ -z "$OTHER_JSON" ]] && { echo "lock: --merge requires --other-json <json>" >&2; exit 2; }
    [[ ! -f "$LOCK_PATH" ]] && { echo "lock: no lock file at $LOCK_PATH" >&2; exit 1; }
    OTHER_JSON="$OTHER_JSON" node -e "
      const fs = require('fs');
      const local = JSON.parse(fs.readFileSync('$LOCK_PATH', 'utf8'));
      const other = JSON.parse(process.env.OTHER_JSON);
      // Per §2.7: standards_versions / pr_corpus_patterns / compliance_versions by union.
      for (const k of ['standards_versions', 'pr_corpus_patterns', 'compliance_versions', 'model_pins']) {
        local[k] = Object.assign({}, local[k] || {}, other[k] || {});
      }
      // rubric / workflow_state / detectors by last-writer-wins (other wins on conflict).
      for (const k of ['rubric', 'detectors']) {
        local[k] = Object.assign({}, local[k] || {}, other[k] || {});
      }
      if (other.workflow_state_hash) local.workflow_state_hash = other.workflow_state_hash;
      if (other.prompt_registry_hash) local.prompt_registry_hash = other.prompt_registry_hash;
      if (other.profile_snapshot_hash) local.profile_snapshot_hash = other.profile_snapshot_hash;
      if (other.quality_standards_directory_hash) local.quality_standards_directory_hash = other.quality_standards_directory_hash;
      fs.writeFileSync('$LOCK_PATH', JSON.stringify(local) + '\n');
    "
    echo "lock: merged" >&2
    exit 0
    ;;
esac
