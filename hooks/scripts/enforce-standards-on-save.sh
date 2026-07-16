#!/usr/bin/env bash
# PostToolUse hook: enforce CTP standards on the config/markup/IaC file just written
# (§28.27). The complement to lint-on-save.sh (which runs eslint/ruff on JS/Py): this runs
# the CTP rule corpus -- k8s/iam/jwt/gha/compose/cfn/sarif/sbom/oas/... + YAML/JSON/MD
# well-formedness + the §28.24 prose-as-code rules on architecture/ADR Markdown -- against
# the single file, via rubric/enforce-file.sh. P0/P1 violations block (exit 2, surfaced to
# the model); P2/P3 are advisory and never block.
#
# Same hardened path model as lint-on-save.sh: reject paths outside the workspace, reject
# symlinked ancestors, skip vendor/build/VCS, strict path allowlist, silent exit 0 on any
# defense-trip. Only a real blocking violation surfaces (exit 2).

set -uo pipefail

INPUT="$(cat)"
command -v node >/dev/null 2>&1 || exit 0

FILE=$(printf '%s' "$INPUT" | node -e '
  let raw = "";
  process.stdin.on("data", c => raw += c);
  process.stdin.on("end", () => {
    try {
      const j = JSON.parse(raw);
      const p = j.tool_input?.file_path || j.tool_input?.path || j.tool_input?.notebook_path || "";
      if (!/^[A-Za-z0-9._/\-~ ]+$/.test(p)) { process.exit(0); }
      process.stdout.write(p);
    } catch { process.exit(0); }
  });
' 2>/dev/null)

[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# Skip vendor / build / VCS dirs early.
case "$FILE" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*|*/.cache/*|*/vendor/*|*/__pycache__/*|*/.venv/*)
    exit 0 ;;
esac

# Only act on the config/markup/IaC kinds the CTP corpus targets (JS/Py are lint-on-save's
# job). enforce-file.sh itself decides which rules apply; this gate just avoids walking the
# catalog for irrelevant file types.
case "$FILE" in
  *.yaml|*.yml|*.json|*.md|*.tf|*.bicep|*.template|*.sarif|*.tpl|Jenkinsfile|*.jenkinsfile) ;;
  *) exit 0 ;;
esac

# Workspace containment (same model as lint-on-save.sh).
WORKSPACE="${CLAUDE_PROJECT_DIR:-$PWD}"
REAL_WS=$(cd "$WORKSPACE" 2>/dev/null && pwd -P) || exit 0
REAL_DIR=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd -P) || exit 0
REAL_FILE="$REAL_DIR/$(basename "$FILE")"
case "$REAL_FILE" in
  "$REAL_WS"/*) ;;
  *) exit 0 ;;
esac

# Reject if any ancestor up to the workspace is a symlink.
p="$REAL_FILE"
while [[ "$p" != "$REAL_WS" && "$p" != "/" && -n "$p" ]]; do
  if [[ -L "$p" ]]; then exit 0; fi
  p=$(dirname "$p")
done

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
ENFORCER="$PLUGIN_ROOT/rubric/enforce-file.sh"
[[ -x "$ENFORCER" || -f "$ENFORCER" ]] || exit 0

set +e
# §35 / CL1: --include-app-code so app-code AND IaC rules are natively enforced on save even
# when the routed 3rd-party tool is absent (parity with the pre-write gate's enforce-write-time.sh).
OUTPUT=$(bash "$ENFORCER" --file "$REAL_FILE" --include-app-code 2>&1)
EC=$?
set -e

# exit 1 from enforce-file = a BLOCKING (P0/P1) violation -> surface to the model (exit 2).
# exit 3 (not_enforced) and advisory-only are not blocked.
if [[ "$EC" -eq 1 ]]; then
  {
    echo "[enforce-standards-on-save] blocking CTP rule violation(s) in:"
    echo "  $REAL_FILE"
    echo
    echo "$OUTPUT"
    echo
    echo "Fix the P0/P1 violation(s) above, or adjust the design. (P2/P3 lines are advisory.)"
  } >&2
  exit 2
fi

# ADR-0008 Wave 3, write-time phase (pragmatic): a Markdown file also runs the whole-or-nothing
# architectural-content bundle. Write-time surfaces a bundle VIOLATION (red) but is lenient on
# not_enforced/incomplete (unadapted members) — the strict gate is the audit-time phase.
case "$REAL_FILE" in
  *.md|*.markdown)
    BUNDLE="$PLUGIN_ROOT/rubric/runners/run-bundle.sh"
    if [[ -f "$BUNDLE" ]]; then
      set +e
      BOUT=$(bash "$BUNDLE" --file "$REAL_FILE" 2>&1); BEC=$?
      set -e
      if [[ "$BEC" -eq 1 ]]; then
        {
          echo "[enforce-standards-on-save] architectural-content bundle violation(s) in:"
          echo "  $REAL_FILE"
          echo
          echo "$BOUT"
        } >&2
        exit 2
      fi
    fi
    ;;
esac

# ADR-0008 write-time phase (the COMPOSITE ENGINE): also run the routed FOSS tools on the file,
# so a rule scraped from a source URL is enforced at write-time by the proper dependency
# (checkov/eslint/...). resolve(file 4-axis) -> route -> run-tool -> SARIF -> verdict. A routed-tool
# violation (red) surfaces inline (exit 2); a missing/unadapted tool (incomplete) is lenient at
# write-time -- the strict whole-tree gate is the audit-time phase (composite-audit.sh).
DISPATCH="$PLUGIN_ROOT/rubric/composite-dispatch.sh"
if [[ -f "$DISPATCH" ]]; then
  set +e
  DOUT=$(bash "$DISPATCH" --file "$REAL_FILE" 2>&1); DEC=$?
  set -e
  if [[ "$DEC" -eq 1 ]]; then
    {
      echo "[enforce-standards-on-save] composite-engine (routed FOSS tool) violation(s) in:"
      echo "  $REAL_FILE"
      echo
      echo "$DOUT"
    } >&2
    exit 2
  fi
fi

exit 0
