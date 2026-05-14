#!/usr/bin/env bash
# sync-memory.sh — keep the per-user auto-memory tree in sync with the repo's master memory tree.
#
# Direction: one-way, docs/memory/  →  ~/.claude/projects/<encoded-repo-path>/memory/
# Conflict resolution: master (repo) always wins; mirror is overwritten.
# Architecture text: docs/memory/project-v19-architecture-text.md is regenerated
#   from docs/architecture-v1.9.md when the canonical is newer than the mirror,
#   so the verbatim text never drifts from the source of truth.
#
# Invoked automatically by hooks/hooks.json on Setup (session start).
# Can also be invoked manually: bash hooks/scripts/sync-memory.sh
#
# Soft-fail by design: any error is reported to stderr but exits 0, so a broken
# memory tree never blocks a session. Block-on-error would be worse than drift.

set -uo pipefail

# --- locate the repo root ---
# Prefer git; fall back to script's parent-parent so this works even if invoked
# outside a git working tree.
if REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fi

MASTER_DIR="$REPO_ROOT/docs/memory"
ARCH_CANONICAL="$REPO_ROOT/docs/architecture-v1.9.md"
ARCH_TEXT_MIRROR="$MASTER_DIR/project-v19-architecture-text.md"

if [[ ! -d "$MASTER_DIR" ]]; then
  echo "[memory-sync] master tree missing at $MASTER_DIR — nothing to sync" >&2
  exit 0
fi

# --- derive the auto-memory mirror path Claude Code uses ---
# Claude Code stores per-user memory at:
#   ~/.claude/projects/<repo-path-with-slashes-replaced-by-dashes>/memory/
# Leading dash because the absolute path starts with /.
REPO_ESCAPED="$(printf '%s' "$REPO_ROOT" | sed 's|/|-|g')"
MIRROR_DIR="$HOME/.claude/projects/${REPO_ESCAPED}/memory"

mkdir -p "$MIRROR_DIR" 2>/dev/null || {
  echo "[memory-sync] cannot create mirror dir $MIRROR_DIR — skipping" >&2
  exit 0
}

# --- step 1: regenerate verbatim architecture-text if canonical is newer ---
# This keeps the verbatim mirror byte-identical with docs/architecture-v1.9.md
# after the chapter-map preamble. Without this step, an architecture edit would
# silently drift from its verbatim mirror.
if [[ -f "$ARCH_CANONICAL" ]]; then
  if [[ ! -f "$ARCH_TEXT_MIRROR" ]] || [[ "$ARCH_CANONICAL" -nt "$ARCH_TEXT_MIRROR" ]]; then
    # Extract the existing preamble (lines before "<!-- begin verbatim text" marker)
    # so we preserve the chapter map and discipline reminders.
    PREAMBLE_FILE="$(mktemp)"
    trap 'rm -f "$PREAMBLE_FILE"' EXIT

    if [[ -f "$ARCH_TEXT_MIRROR" ]]; then
      # Keep lines up to and including the begin-marker
      awk '/<!-- begin verbatim text from docs\/architecture-v1.9.md -->/ { print; found=1; exit } { print }' \
        "$ARCH_TEXT_MIRROR" > "$PREAMBLE_FILE"

      # If marker not found, fall back to whole file as preamble (defensive)
      if ! grep -q '<!-- begin verbatim text from docs/architecture-v1.9.md -->' "$PREAMBLE_FILE"; then
        cp "$ARCH_TEXT_MIRROR" "$PREAMBLE_FILE"
        echo "" >> "$PREAMBLE_FILE"
        echo "<!-- begin verbatim text from docs/architecture-v1.9.md -->" >> "$PREAMBLE_FILE"
      fi
    else
      # No prior mirror — minimal preamble
      {
        echo "---"
        echo "name: Claude TDD Pro architecture — full text (verbatim mirror)"
        echo "description: Verbatim mirror of docs/architecture-v1.9.md auto-refreshed by hooks/scripts/sync-memory.sh on session start. Source of truth is the repo file."
        echo "type: project"
        echo "---"
        echo ""
        echo "<!-- begin verbatim text from docs/architecture-v1.9.md -->"
      } > "$PREAMBLE_FILE"
    fi

    # Rebuild: preamble + blank + canonical content
    {
      cat "$PREAMBLE_FILE"
      echo ""
      cat "$ARCH_CANONICAL"
    } > "$ARCH_TEXT_MIRROR.tmp" && mv "$ARCH_TEXT_MIRROR.tmp" "$ARCH_TEXT_MIRROR"
  fi
fi

# --- step 2: copy master → mirror (overwrite mirror; master is canonical) ---
COPIED=0
for src in "$MASTER_DIR"/*.md; do
  [[ -e "$src" ]] || continue
  base="$(basename "$src")"
  dst="$MIRROR_DIR/$base"
  # Only copy if differs (avoids touching mtimes unnecessarily, keeps logs quiet)
  if ! cmp -s "$src" "$dst" 2>/dev/null; then
    cp "$src" "$dst" && COPIED=$((COPIED + 1))
  fi
done

# --- step 3: report (stderr so it doesn't pollute tool stdout) ---
TOTAL="$(ls "$MASTER_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$COPIED" -gt 0 ]]; then
  echo "[memory-sync] synced $COPIED of $TOTAL file(s) from $MASTER_DIR → $MIRROR_DIR" >&2
fi

exit 0
