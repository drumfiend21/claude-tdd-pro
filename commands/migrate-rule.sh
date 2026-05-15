#!/usr/bin/env bash
# /migrate-rule — E-10 deprecation lifecycle migration tool per §16:
# "/migrate-rule <deprecated> --to <replacement> updates profiles +
# ADRs + inline suppressions; deprecated >=1 minor version before removal."
set -uo pipefail

OLD=""; NEW=""; PROFILE=""; TREE=""; PATHS=""; UPDATE_ADRS=0
UPDATE_INLINE=0; DRY_RUN=0; EMIT_AUDIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) NEW="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    --update-adrs) UPDATE_ADRS=1; shift ;;
    --update-inline-suppressions) UPDATE_INLINE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: migrate-rule.sh <old-rule-id> --to <new-rule-id> [--profile <p>] [--tree <d>] [--paths <glob>] [--update-adrs] [--update-inline-suppressions] [--dry-run] [--emit-audit <jsonl>]"; exit 0 ;;
    -*) echo "migrate-rule: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$OLD" ]] && OLD="$1" || { echo "migrate-rule: unexpected arg: $1" >&2; exit 2; }; shift ;;
  esac
done
[[ -z "$OLD" || -z "$NEW" ]] && { echo "migrate-rule: <old-rule-id> + --to <new-rule-id> required" >&2; exit 2; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "migrate-rule: dry-run; would migrate $OLD -> $NEW (no writes)" >&2
  exit 0
fi

# Update profile.yaml: replace `<old>:` with `<new>:`.
if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  sed -i.bak "s|${OLD}:|${NEW}:|g" "$PROFILE"
  rm -f "${PROFILE}.bak"
fi

# Update ADRs: append "Superseded: <new>" near rule reference.
if [[ "$UPDATE_ADRS" -eq 1 ]]; then
  for adr in docs/adr/*.md; do
    [[ -f "$adr" ]] || continue
    if grep -q "$OLD" "$adr"; then
      echo "" >> "$adr"
      echo "Superseded: $OLD -> $NEW" >> "$adr"
    fi
  done
fi

# Update inline suppressions in source files. The --paths arg is a
# shell-style glob (src/**/*.ts); convert trailing extension to a
# find -name pattern (portable on macOS).
if [[ "$UPDATE_INLINE" -eq 1 && -n "$PATHS" ]]; then
  EXT_PATTERN=$(echo "$PATHS" | grep -oE '\*\.[a-zA-Z0-9]+$' || true)
  [[ -z "$EXT_PATTERN" ]] && EXT_PATTERN="*"
  find . -name "$EXT_PATTERN" -type f 2>/dev/null | while read -r f; do
    if grep -q "$OLD" "$f"; then
      sed -i.bak "s|${OLD}|${NEW}|g" "$f"
      rm -f "${f}.bak"
    fi
  done
fi

if [[ -n "$EMIT_AUDIT" ]]; then
  mkdir -p "$(dirname "$EMIT_AUDIT")"
  printf '{"action":"rule-migrated","from":"%s","to":"%s","ts":"%s"}\n' "$OLD" "$NEW" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$EMIT_AUDIT"
fi
echo "migrate-rule: migrated $OLD -> $NEW" >&2
