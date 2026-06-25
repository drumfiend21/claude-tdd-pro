#!/usr/bin/env bash
# rubric/composite-audit.sh — ADR-0008 Wave 3: the AUDIT-TIME (whole-tree) phase of two-phase
# enforcement. Walks an application tree and drives the composite engine across every file:
# code-shape tools via composite-dispatch.sh, and the architectural-content bundle via
# run-bundle.sh for every Markdown file. Aggregates into one tree verdict under a zero-violation
# gate (audit-time is strict: any violation is red, unless explicitly deviated).
#
# The complement is the WRITE-TIME phase (per-file, pragmatic): hooks/scripts/enforce-standards-
# on-save.sh runs on each Edit/Write. Same engine, two moments.
#
# CLI: --root <dir> [--strict] [--json]
# stderr: per file `audit file=<f> verdict=<green|red|incomplete|na>`; summary
#         `composite-audit root=<r> status=<green|red|incomplete> files=<n> red=<r> incomplete=<i>`
# Exit: 0 green | 1 red (zero-violation gate) | 3 incomplete | 2 usage.

set -uo pipefail
ROOT=""; STRICT=0; JSON=0; PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --profile) PROFILE="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: composite-audit.sh --root <dir> [--strict] [--profile <profile.yaml>] [--json]" >&2; exit 0 ;;
    *) echo "composite-audit: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && { echo "composite-audit: --root required" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "composite-audit: not a directory: $ROOT" >&2; exit 2; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
DISPATCH="$PLUGIN_ROOT/rubric/composite-dispatch.sh"
BUNDLE="$PLUGIN_ROOT/rubric/runners/run-bundle.sh"
ENFORCER="$PLUGIN_ROOT/rubric/enforce-file.sh"

# Enumerate candidate files (skip vendor/build/VCS).
FILES="$(ROOT="$ROOT" node -e '
  const fs=require("fs"),path=require("path");const root=process.env.ROOT;const out=[];
  (function walk(d){let es=[];try{es=fs.readdirSync(d,{withFileTypes:true})}catch(e){return}
    for(const e of es){const p=path.join(d,e.name);
      if(e.isDirectory()){if(![".git","node_modules","dist","build",".next","coverage","vendor","__pycache__",".venv"].includes(e.name))walk(p);}
      else if(e.isFile())out.push(p);}})(root);
  process.stdout.write(out.join("\n"));
')"

sa="$STRICT"; nred=0; ninc=0; nfiles=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # A file is RED on any violation; GREEN once it has been VERIFIED (the always-present in-repo
  # detectors ran clean, or any present routed tool ran clean) — absent OPTIONAL tools do not make
  # it incomplete; INCOMPLETE only when nothing could verify it. (Never a vacuous green: the
  # dependency-free in-repo detectors always run and give a real verdict.)
  red=0; verified=0
  # in-repo rule detectors + prose-as-code (enforce-file; dependency-free, deterministic).
  # The §16 config plane is threaded through: --profile resolves effective per-file severity /
  # enable-disable / overrides before enforcement (no-op when --profile is absent).
  ea=(--file "$f" --quiet); [ -n "$PROFILE" ] && ea+=(--profile "$PROFILE")
  bash "$ENFORCER" "${ea[@]}" >/dev/null 2>/dev/null
  estat=$?
  case "$estat" in 1) red=1 ;; 0) verified=1 ;; esac
  # routed FOSS tools (composite-dispatch resolves + routes + runs)
  da=(--file "$f"); [ "$sa" -eq 1 ] && da+=(--strict)
  bash "$DISPATCH" "${da[@]}" >/dev/null 2>/tmp/_ca.$$ || true
  dstat=$(grep -oE 'status=[a-z]+' /tmp/_ca.$$ 2>/dev/null | tail -1 | cut -d= -f2)
  case "$dstat" in red) red=1 ;; green) verified=1 ;; esac
  # architectural-content bundle for Markdown
  case "$f" in
    *.md|*.markdown)
      ba=(--file "$f"); [ "$sa" -eq 1 ] && ba+=(--strict)
      bash "$BUNDLE" "${ba[@]}" >/dev/null 2>/tmp/_cb.$$ || true
      bstat=$(grep -oE 'status=[a-z]+' /tmp/_cb.$$ 2>/dev/null | tail -1 | cut -d= -f2)
      case "$bstat" in red) red=1 ;; green) verified=1 ;; esac
      rm -f /tmp/_cb.$$ ;;
  esac
  rm -f /tmp/_ca.$$
  if [ "$red" -eq 1 ]; then v=red; elif [ "$verified" -eq 1 ]; then v=green; else v=incomplete; fi
  case "$v" in
    red) nred=$((nred+1)); nfiles=$((nfiles+1)); echo "audit file=$f verdict=red" >&2 ;;
    incomplete) ninc=$((ninc+1)); nfiles=$((nfiles+1)); echo "audit file=$f verdict=incomplete" >&2 ;;
    *) : ;;  # green/na files are not enumerated individually
  esac
done <<EOF
$FILES
EOF

if [ "$nred" -gt 0 ]; then status="red"; rc=1
elif [ "$ninc" -gt 0 ]; then status="incomplete"; rc=3
else status="green"; rc=0; fi
[ "$JSON" -eq 1 ] && printf '{"root":"%s","status":"%s","red":%d,"incomplete":%d}\n' "$ROOT" "$status" "$nred" "$ninc"
echo "composite-audit root=$ROOT status=$status files_flagged=$((nred+ninc)) red=$nred incomplete=$ninc" >&2
exit $rc
