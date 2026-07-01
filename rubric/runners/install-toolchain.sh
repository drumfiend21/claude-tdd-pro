#!/usr/bin/env bash
# rubric/runners/install-toolchain.sh — provision the composite-engine FOSS toolchain
# (ADR-0008 Wave 2). Reads rubric/runners/toolchain.json and installs each tool via its
# installer (npm / pipx). Called at CTP install time (scripts/install.sh) so the engine's
# tools are present in production — the §28.28 hard-require policy then treats a missing
# REQUIRED tool as a broken install, not normal operation. GCTP gets the toolchain by
# consuming CTP (CTP's installer provisions it).
#
# Idempotent (skips an already-present tool). Network-tolerant + best-effort (a failed
# install is logged, never fatal — the engine degrades that tool per the missing-tool policy).
# License posture: permissive tools install by default; GPL/LGPL (invoke_only) tools also
# install unless --permissive-only is given (their commercial USE is unrestricted; CTP never
# bundles/redistributes them). Binary-installer tools are not auto-installed (platform-specific);
# their upstream URL is printed.
#
# CLI: [--dry-run] [--verify] [--permissive-only] [--manifest <path>]
#   --dry-run         print the plan, install nothing
#   --verify          report present/absent per tool, install nothing
#   --permissive-only skip GPL/LGPL (invoke_only) tools
# stderr: per tool `toolchain tool=<t> license=<l> status=<present|installed|skipped|manual|failed>`
#         summary `toolchain present=<p> installed=<i> manual=<m> failed=<f> skipped=<s>`
# Exit: 0 ok (best-effort) | 2 usage/manifest error.

set -uo pipefail
DRY=0; VERIFY=0; PERMISSIVE_ONLY=0; MANIFEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --verify) VERIFY=1; shift ;;
    --permissive-only) PERMISSIVE_ONLY=1; shift ;;
    --manifest) MANIFEST="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: install-toolchain.sh [--dry-run] [--verify] [--permissive-only] [--manifest <path>]" >&2; exit 0 ;;
    *) echo "install-toolchain: unknown arg: $1" >&2; exit 2 ;;
  esac
done
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
[ -z "$MANIFEST" ] && MANIFEST="$PLUGIN_ROOT/rubric/runners/toolchain.json"
[ -f "$MANIFEST" ] || { echo "install-toolchain: manifest missing: $MANIFEST" >&2; exit 2; }
command -v node >/dev/null 2>&1 || { echo "install-toolchain: node required to read manifest" >&2; exit 2; }

# Read the manifest into newline records: tool|installer|package|bin|license|invoke_only|install_url
RECORDS="$(MANIFEST="$MANIFEST" node -e '
  const m=JSON.parse(require("fs").readFileSync(process.env.MANIFEST,"utf8"));
  for(const t of (m.tools||[])) process.stdout.write([t.tool,t.installer,t.package,(t.bin||t.tool),t.license,(t.invoke_only?"1":"0"),(t.install_url||"")].join("|")+"\n");
')"
[ -z "$RECORDS" ] && { echo "install-toolchain: no tools in manifest" >&2; exit 2; }

p=0; i=0; man=0; f=0; sk=0
while IFS='|' read -r tool installer pkg bin lic invoke url; do
  [ -z "$tool" ] && continue
  if [ "$PERMISSIVE_ONLY" -eq 1 ] && [ "$invoke" = "1" ]; then
    echo "toolchain tool=$tool license=$lic status=skipped reason=permissive-only" >&2; sk=$((sk+1)); continue
  fi
  if command -v "$bin" >/dev/null 2>&1; then
    echo "toolchain tool=$tool license=$lic status=present" >&2; p=$((p+1)); continue
  fi
  if [ "$VERIFY" -eq 1 ]; then
    echo "toolchain tool=$tool license=$lic status=absent" >&2; continue
  fi
  # Determine the install command per installer kind.
  cmd=""
  case "$installer" in
    npm)    command -v npm  >/dev/null 2>&1 && cmd="npm install -g $pkg" ;;
    pipx)   if command -v pipx >/dev/null 2>&1; then cmd="pipx install $pkg";
            elif command -v pip >/dev/null 2>&1; then cmd="pip install --user $pkg"; fi ;;
    cargo)  command -v cargo >/dev/null 2>&1 && cmd="cargo install $pkg" ;;
    go)     command -v go    >/dev/null 2>&1 && cmd="go install $pkg@latest" ;;
    gem)    command -v gem   >/dev/null 2>&1 && cmd="gem install $pkg" ;;
    binary) echo "toolchain tool=$tool license=$lic status=manual url=$url" >&2; man=$((man+1)); continue ;;
    manual) echo "toolchain tool=$tool license=$lic status=manual url=$url" >&2; man=$((man+1)); continue ;;
  esac
  if [ -z "$cmd" ]; then
    echo "toolchain tool=$tool license=$lic status=failed reason=no-installer" >&2; f=$((f+1)); continue
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "toolchain tool=$tool license=$lic status=plan cmd=\"$cmd\"" >&2; continue
  fi
  if $cmd >/dev/null 2>&1; then
    echo "toolchain tool=$tool license=$lic status=installed" >&2; i=$((i+1))
  else
    echo "toolchain tool=$tool license=$lic status=failed reason=install-error" >&2; f=$((f+1))
  fi
done <<EOF
$RECORDS
EOF

echo "toolchain present=$p installed=$i manual=$man failed=$f skipped=$sk" >&2
exit 0
