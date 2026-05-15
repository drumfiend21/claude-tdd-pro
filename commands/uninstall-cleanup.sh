#!/usr/bin/env bash
# /uninstall-cleanup — O-3 plugin lifecycle per §16:
# "category-by-category; never auto-deletes evidence/audit-log".
set -uo pipefail

CATEGORY=""; CONFIRM=""; EMIT_AUDIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --category) CATEGORY="$2"; shift 2 ;;
    --confirm) CONFIRM="$2"; shift 2 ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    --dry-run) CONFIRM=""; shift ;;
    -h|--help) echo "Usage: uninstall-cleanup.sh --category <cache|config|all> [--confirm yes] [--emit-audit <path>] [--dry-run]"; exit 0 ;;
    *) echo "uninstall-cleanup: unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$CATEGORY" ]] && { echo "uninstall-cleanup: --category required" >&2; exit 2; }

declare -a TARGETS
case "$CATEGORY" in
  cache) TARGETS=(.claude-tdd-pro/cache) ;;
  config) TARGETS=(.claude-tdd-pro/STANDARDS-URLS.yaml .claude-tdd-pro/COMPLIANCE-URLS.yaml .claude-tdd-pro/PR-SOURCES.yaml) ;;
  all) TARGETS=(.claude-tdd-pro/cache .claude-tdd-pro/standards-cache .claude-tdd-pro/compliance-cache) ;;
  *) echo "uninstall-cleanup: unknown category: $CATEGORY" >&2; exit 2 ;;
esac

if [[ "$CONFIRM" != "yes" ]]; then
  for t in "${TARGETS[@]}"; do
    if [[ -e "$t" ]]; then
      echo "uninstall-cleanup: would remove $t" >&2
    fi
  done
  exit 0
fi

# Hard guard: NEVER touch compliance/evidence or compliance/audit-checkpoints.
PROTECTED=(compliance/evidence compliance/audit-checkpoints)
for t in "${TARGETS[@]}"; do
  for p in "${PROTECTED[@]}"; do
    if [[ "$t" == "$p" || "$t" == "$p"/* ]]; then
      echo "uninstall-cleanup: refusing to remove protected path $t" >&2
      continue 2
    fi
  done
  if [[ -e "$t" ]]; then
    rm -rf "$t"
    echo "uninstall-cleanup: removed $t" >&2
    if [[ -n "$EMIT_AUDIT" ]]; then
      mkdir -p "$(dirname "$EMIT_AUDIT")"
      printf '{"action":"category-removed","category":"%s","target":"%s","ts":"%s"}\n' \
        "$CATEGORY" "$t" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$EMIT_AUDIT"
    fi
  fi
done
exit 0
