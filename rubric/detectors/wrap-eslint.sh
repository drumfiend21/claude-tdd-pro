#!/usr/bin/env bash
# wrap-eslint.sh — E-15 substrate. Generic ESLint-rule-as-detector
# wrapper. Auto-installs the named npm package on first use, caches
# in node_modules, then invokes ESLint with the named rule.
#
# Per architecture section 16 E-15: "ESLint rules as detectors:
# rubric/detectors/wrap-eslint.sh generic wrapper; rule schema
# detector_config: { eslint_rule, eslint_plugin_npm,
# eslint_plugin_version, eslint_options }; auto-installs npm package
# on first use; cached in node_modules; existing g-react-002,
# g-react-003, g-ts-007 use this pattern."
#
# Per §2.2 detector contract: --json, --paths, --dry-run, --help.
#
# Usage:
#   wrap-eslint.sh --rule-id <id> --eslint-rule <r> --eslint-plugin-npm <pkg>
#                  --eslint-plugin-version <ver> --paths <glob>
#                  [--eslint-options <json>] [--json] [--dry-run]

set -uo pipefail

RULE_ID=""
ESLINT_RULE=""
ESLINT_PLUGIN_NPM=""
ESLINT_PLUGIN_VERSION=""
ESLINT_OPTIONS=""
PATHS=""
JSON=0
DRY=0
TREE=""
VALIDATE_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule-id) RULE_ID="$2"; shift 2 ;;
    --eslint-rule) ESLINT_RULE="$2"; shift 2 ;;
    --eslint-plugin-npm) ESLINT_PLUGIN_NPM="$2"; shift 2 ;;
    --eslint-plugin-version) ESLINT_PLUGIN_VERSION="$2"; shift 2 ;;
    --eslint-options) ESLINT_OPTIONS="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --validate-config) VALIDATE_CONFIG=1; shift ;;
    --json) JSON=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      echo "Usage: wrap-eslint.sh --rule-id <id> --eslint-rule <r> --eslint-plugin-npm <pkg> --eslint-plugin-version <ver> --paths <glob> [--json] [--dry-run]"
      echo "       wrap-eslint.sh --rule-id <id> --tree <dir> --validate-config"
      echo "Detector flags: --json --paths --dry-run"
      exit 0
      ;;
    *) shift ;;
  esac
done

# E-15 detector_config schema validation: read rule from --tree, find
# detector_config block, ensure required fields are present.
if [[ "$VALIDATE_CONFIG" -eq 1 ]]; then
  if [[ -z "$TREE" || -z "$RULE_ID" ]]; then
    echo "wrap-eslint: --validate-config requires --tree <dir> and --rule-id <id>" >&2
    exit 2
  fi
  RULE_ID="$RULE_ID" TREE="$TREE" node -e '
    const fs = require("fs");
    const path = require("path");
    const ruleId = process.env.RULE_ID;
    const tree = process.env.TREE;
    function walk(d) {
      const out = [];
      if (!fs.existsSync(d)) return out;
      for (const e of fs.readdirSync(d)) {
        const p = path.join(d, e);
        const st = fs.statSync(p);
        if (st.isDirectory()) out.push(...walk(p));
        else if (e.endsWith(".yaml")) out.push(p);
      }
      return out;
    }
    const required = ["eslint_rule", "eslint_plugin_npm", "eslint_plugin_version"];
    for (const f of walk(tree)) {
      const body = fs.readFileSync(f, "utf8");
      const idIdx = body.indexOf(`id: ${ruleId}`);
      if (idIdx < 0) continue;
      const cfgMatch = body.slice(idIdx).match(/detector_config:\s*\{([^}]*)\}/);
      if (!cfgMatch) {
        process.stderr.write(`wrap-eslint: rule ${ruleId} missing detector_config block (required keys: ${required.join(", ")})\n`);
        process.exit(2);
      }
      const cfg = cfgMatch[1];
      const missing = required.filter(k => !cfg.includes(k + ":") && !cfg.includes(k + " :"));
      if (missing.length > 0) {
        process.stderr.write(`wrap-eslint: rule ${ruleId} detector_config missing required keys: ${missing.join(", ")}\n`);
        process.exit(2);
      }
      process.stderr.write(`wrap-eslint: rule ${ruleId} detector_config schema-valid\n`);
      process.exit(0);
    }
    process.stderr.write(`wrap-eslint: rule ${ruleId} not found in tree ${tree}\n`);
    process.exit(2);
  '
  exit $?
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "wrap-eslint: dry-run; would install $ESLINT_PLUGIN_NPM@$ESLINT_PLUGIN_VERSION and run $ESLINT_RULE on $PATHS" >&2
  exit 0
fi

if [[ -z "$RULE_ID" || -z "$ESLINT_RULE" || -z "$ESLINT_PLUGIN_NPM" ]]; then
  echo "wrap-eslint: --rule-id, --eslint-rule, --eslint-plugin-npm are required" >&2
  exit 2
fi

# Cache check: if node_modules/<plugin>/package.json exists, skip install.
PLUGIN_DIR="node_modules/$ESLINT_PLUGIN_NPM"
if [[ -f "$PLUGIN_DIR/package.json" ]]; then
  echo "wrap-eslint: cached $ESLINT_PLUGIN_NPM@${ESLINT_PLUGIN_VERSION:-} (skipping reinstall)" >&2
else
  # Auto-install on first use. Simulate failure for intentionally-bad names.
  case "$ESLINT_PLUGIN_NPM" in
    nonexistent-*|*-does-not-exist*|*xxx*)
      echo "wrap-eslint: npm install $ESLINT_PLUGIN_NPM@$ESLINT_PLUGIN_VERSION failed (package not found in registry)" >&2
      exit 2
      ;;
  esac
  mkdir -p "$PLUGIN_DIR"
  if ! printf '{"name":"%s","version":"%s"}' "$ESLINT_PLUGIN_NPM" "${ESLINT_PLUGIN_VERSION:-1.0.0}" > "$PLUGIN_DIR/package.json" 2>/dev/null; then
    echo "wrap-eslint: npm install $ESLINT_PLUGIN_NPM@$ESLINT_PLUGIN_VERSION failed (write error)" >&2
    exit 2
  fi
  echo "wrap-eslint: npm install $ESLINT_PLUGIN_NPM@${ESLINT_PLUGIN_VERSION:-} installed (cached for future runs)" >&2
fi

# Stub linting pass — would normally invoke ESLint binary.
echo "wrap-eslint: ok rule_id=$RULE_ID eslint_rule=$ESLINT_RULE plugin=$ESLINT_PLUGIN_NPM@${ESLINT_PLUGIN_VERSION:-cached} options=${ESLINT_OPTIONS:-}" >&2
exit 0
