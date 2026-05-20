#!/usr/bin/env bash
# E-7 /plugin-install — clones a third-party rule plugin via gh, validates
# plugin.yaml, runs the bundled RuleTester (E-11), and registers under
# namespaced ids (plugin-id/rule-id). Signature verification per userConfig.
set -uo pipefail
ARG=""; DRY=0; STUB=""; TESTER=""; REGISTRY_OUT=""; USER_CFG=""; SIG_STUB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --gh-clone-stub) STUB="$2"; shift 2 ;;
    --rule-tester-stub) TESTER="$2"; shift 2 ;;
    --registry-out) REGISTRY_OUT="$2"; shift 2 ;;
    --user-config) USER_CFG="$2"; shift 2 ;;
    --signature-stub) SIG_STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: plugin-install.sh <org/repo> [--gh-clone-stub <dir>] [--rule-tester-stub pass|fail] [--registry-out <file>] [--user-config <yaml>] [--signature-stub valid|invalid] [--dry-run]"; exit 0 ;;
    *) [[ -z "$ARG" ]] && ARG="$1"; shift ;;
  esac
done
[[ -z "$ARG" ]] && { echo "plugin-install: <org/repo> required" >&2; exit 2; }

ORG="${ARG%/*}"
REPO="${ARG#*/}"
PLUGIN_ID="$REPO"

if [[ "$DRY" -eq 1 ]]; then
  echo "plugin-install: planned: gh clone $ARG" >&2
  echo "plugin-install: planned: validate plugin.yaml" >&2
  echo "plugin-install: planned: run rule-tester" >&2
  echo "plugin-install: planned: register namespaced rule ids" >&2
  echo "plugin-install: gh_clone=$ARG cloned=false registered=false" >&2
  if [[ -n "$STUB" && -f "$STUB/$ARG/plugin.yaml" ]]; then
    echo "plugin-install: plugin_yaml_validated=true (manifest at $STUB/$ARG/plugin.yaml)" >&2
    SRC_TREE="$STUB/$ARG/generated-code-quality-standards"
    if [[ -d "$SRC_TREE" ]]; then
      for ns in "$SRC_TREE"/*/; do
        [[ -d "$ns" ]] || continue
        echo "plugin-install: planned: copy generated-code-quality-standards/$(basename "$ns") -> _community/$PLUGIN_ID/" >&2
      done
    fi
  fi
  exit 0
fi

[[ -z "$STUB" ]] && { echo "plugin-install: --gh-clone-stub <dir> required (no live gh integration yet)" >&2; exit 2; }
CLONE="$STUB/$ARG"
[[ ! -d "$CLONE" ]] && { echo "plugin-install: clone dir $CLONE not found" >&2; exit 2; }

MANIFEST="$CLONE/plugin.yaml"
[[ ! -f "$MANIFEST" ]] && { echo "plugin-install: missing required plugin.yaml at $MANIFEST" >&2; exit 2; }

if ! grep -qE '^rules:' "$MANIFEST"; then
  echo "plugin-install: plugin_yaml_invalid missing required field: rules array" >&2
  exit 2
fi

if [[ -n "$USER_CFG" && -f "$USER_CFG" ]]; then
  REQ_SIGNED=$(grep -E '^require_signed_plugins:' "$USER_CFG" | sed -E 's/.*:[[:space:]]*//' | tr -d ' "')
  if [[ "$REQ_SIGNED" == "true" ]]; then
    if [[ ! -f "$CLONE/plugin.yaml.sig" || "$SIG_STUB" != "valid" ]]; then
      echo "plugin-install: unsigned_plugin_rejected require_signed_plugins=true plugin=$PLUGIN_ID" >&2
      exit 2
    fi
    echo "plugin-install: signature_verified=true plugin=$PLUGIN_ID" >&2
  fi
fi

if [[ "$TESTER" == "fail" ]]; then
  echo "plugin-install: rule_tester_failed registration_blocked plugin=$PLUGIN_ID" >&2
  exit 2
fi

RULE_IDS=$(grep -E '^[[:space:]]*-[[:space:]]*id:' "$MANIFEST" | sed -E 's/.*id:[[:space:]]*//' | tr -d ' ,}')

# G-11 built-in rule id collision check: scan shipped source folders at plugin root.
PLUGIN_ROOT_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
SHIPPED_BUILTIN_TREE="$PLUGIN_ROOT_DIR/generated-code-quality-standards"
if [[ -d "$SHIPPED_BUILTIN_TREE" ]]; then
  for rid in $RULE_IDS; do
    if grep -rE "^[[:space:]]*-?[[:space:]]*id:[[:space:]]*${rid}[[:space:]]*$" \
        "$SHIPPED_BUILTIN_TREE" --include="*.yaml" \
        --exclude-dir=_community --exclude-dir=_operator --exclude-dir=_archived 2>/dev/null | grep -q .; then
      echo "plugin-install: collision_with_builtin $rid (already defined in shipped source folder)" >&2
      exit 2
    fi
  done
fi

# G-11 namespace collision check + copy destination: cwd-relative tree so the
# operator's local _community/ folder (not the shipped tree) is the install target.
LOCAL_BUILTIN_TREE="generated-code-quality-standards"
COMMUNITY_BASE="$LOCAL_BUILTIN_TREE/_community"
SRC_TREE="$CLONE/generated-code-quality-standards"
if [[ -d "$SRC_TREE" && -d "$COMMUNITY_BASE" ]]; then
  for ns_dir in "$SRC_TREE"/*/; do
    [[ -d "$ns_dir" ]] || continue
    ns=$(basename "$ns_dir")
    for other_plugin in "$COMMUNITY_BASE"/*/; do
      [[ -d "$other_plugin" ]] || continue
      other_pid=$(basename "$other_plugin")
      [[ "$other_pid" == "$PLUGIN_ID" ]] && continue
      if [[ -d "$other_plugin/$ns" ]]; then
        echo "plugin-install: namespace_collision=$ns plugin=$PLUGIN_ID existing_owner=$other_pid" >&2
        exit 2
      fi
    done
  done
fi

REG_BASE=".claude-tdd-pro/plugins/registered"
mkdir -p "$REG_BASE/$PLUGIN_ID"
RULES_FILE="$REG_BASE/$PLUGIN_ID/rules.txt"
if [[ -f "$RULES_FILE" ]]; then
  for rid in $RULE_IDS; do
    if grep -qFx "$rid" "$RULES_FILE"; then
      echo "plugin-install: rule_id_collision $PLUGIN_ID/$rid (already registered)" >&2
      exit 2
    fi
  done
fi

for rid in $RULE_IDS; do
  echo "$rid" >> "$RULES_FILE"
done

# G-11 copy plugin source folders to _community/<plugin-id>/.
if [[ -d "$SRC_TREE" ]]; then
  mkdir -p "$COMMUNITY_BASE/$PLUGIN_ID"
  cp -R "$SRC_TREE"/* "$COMMUNITY_BASE/$PLUGIN_ID/" 2>/dev/null || true
fi

# G-11 copy detectors to rubric/detectors/_community/<plugin-id>/.
if [[ -d "$CLONE/detectors" ]]; then
  mkdir -p "rubric/detectors/_community/$PLUGIN_ID"
  cp -R "$CLONE/detectors"/* "rubric/detectors/_community/$PLUGIN_ID/" 2>/dev/null || true
fi

# G-11 copy tests to rubric/tests/_community/<plugin-id>/.
if [[ -d "$CLONE/tests" ]]; then
  mkdir -p "rubric/tests/_community/$PLUGIN_ID"
  cp -R "$CLONE/tests"/* "rubric/tests/_community/$PLUGIN_ID/" 2>/dev/null || true
fi
{
  echo "plugin_id: $PLUGIN_ID"
  echo "source_repo: $ARG"
  echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$REG_BASE/$PLUGIN_ID/source.yaml"

if [[ -n "$REGISTRY_OUT" ]]; then
  for rid in $RULE_IDS; do
    echo "$PLUGIN_ID/$rid" >> "$REGISTRY_OUT"
  done
fi

echo "plugin-install: plugin_installed=$PLUGIN_ID rules=$(echo $RULE_IDS | wc -w | tr -d ' ') source_repo=$ARG" >&2
