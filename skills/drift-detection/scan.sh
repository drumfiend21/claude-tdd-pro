#!/usr/bin/env bash
# F-4 drift-detection scan: post-commit code-side bypass scanner.
# Architecture §3 F-4: scans for `// rubric: ignore`, `--no-verify`,
# repeated bypass; tracks E-5 inline suppressions.
set -uo pipefail

PATHS=""
GIT_ROOT=""
SUPPRESSIONS_DIR=""
OUT=""
DRY_RUN=0
POST_COMMIT=0
REPEATED_THRESHOLD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --paths) PATHS="$2"; shift 2 ;;
    --git-root) GIT_ROOT="$2"; shift 2 ;;
    --suppressions-dir) SUPPRESSIONS_DIR="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --post-commit) POST_COMMIT=1; shift ;;
    --repeated-bypass-threshold) REPEATED_THRESHOLD="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: scan.sh [--paths <dir>] [--git-root <dir>] [--suppressions-dir <dir>] --out <jsonl> [--dry-run] [--post-commit] [--repeated-bypass-threshold <N>]" >&2
      exit 0
      ;;
    *) shift ;;
  esac
done

[[ -z "$OUT" ]] && { echo "scan: --out <jsonl> required" >&2; exit 2; }

FINDINGS=""
COMMITS_SCANNED=0

emit() {
  if [[ -z "$FINDINGS" ]]; then
    FINDINGS="$1"
  else
    FINDINGS="$FINDINGS
$1"
  fi
}

# (1) Inline `rubric: ignore` bypass scan.
if [[ -n "$PATHS" && -d "$PATHS" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    COUNT=$(grep -ci 'rubric: ignore' "$f" 2>/dev/null || true)
    [[ -z "$COUNT" || "$COUNT" -eq 0 ]] && continue
    SEVERITY="finding"
    if [[ "$REPEATED_THRESHOLD" -gt 0 && "$COUNT" -ge "$REPEATED_THRESHOLD" ]]; then
      SEVERITY="escalated"
    fi
    emit "$(printf '{"type":"rubric_ignore","path":"%s","count":%d,"severity":"%s"}' "$f" "$COUNT" "$SEVERITY")"
  done < <(find "$PATHS" -type f 2>/dev/null)
fi

# (2) `--no-verify` git-log scan.
if [[ -n "$GIT_ROOT" && -d "$GIT_ROOT/.git" ]]; then
  if [[ "$POST_COMMIT" -eq 1 ]]; then
    LOG=$(git -C "$GIT_ROOT" log -1 --format='%H%n%B%n---END---' 2>/dev/null)
    COMMITS_SCANNED=1
  else
    LOG=$(git -C "$GIT_ROOT" log --format='%H%n%B%n---END---' 2>/dev/null)
    COMMITS_SCANNED=$(git -C "$GIT_ROOT" log --format='%H' 2>/dev/null | wc -l | tr -d ' ')
  fi
  CURRENT_SHA=""
  CURRENT_BODY=""
  while IFS= read -r line; do
    if [[ "$line" = "---END---" ]]; then
      if echo "$CURRENT_BODY" | grep -qiE 'skipped|no.verify|--no-verify'; then
        emit "$(printf '{"type":"no_verify","commit":"%s"}' "$CURRENT_SHA")"
      fi
      CURRENT_SHA=""
      CURRENT_BODY=""
    elif [[ -z "$CURRENT_SHA" ]]; then
      CURRENT_SHA="$line"
    else
      CURRENT_BODY="$CURRENT_BODY $line"
    fi
  done <<< "$LOG"
fi

# (3) E-5 inline-suppression log tracking.
if [[ -n "$SUPPRESSIONS_DIR" && -d "$SUPPRESSIONS_DIR" ]]; then
  for f in "$SUPPRESSIONS_DIR"/*.jsonl; do
    [[ -f "$f" ]] || continue
    RULE=$(basename "$f" .jsonl)
    COUNT=$(wc -l < "$f" | tr -d ' ')
    emit "$(printf '{"type":"e5_suppression","rule":"%s","suppression_count":%d}' "$RULE" "$COUNT")"
  done
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "scan: dry_run=true \"commits_scanned\":$COMMITS_SCANNED" >&2
  if [[ -n "$FINDINGS" ]]; then
    while IFS= read -r f; do echo "scan: $f" >&2; done <<< "$FINDINGS"
  fi
  exit 0
fi

if [[ -n "$FINDINGS" ]]; then
  printf '%s\n' "$FINDINGS" > "$OUT"
else
  : > "$OUT"
fi

echo "scan: \"commits_scanned\":$COMMITS_SCANNED out=$OUT" >&2

# Bypass-style findings exit non-zero (rubric_ignore + no_verify);
# E-5 suppression tracking alone is informational and exits 0.
if echo "$FINDINGS" | grep -qE '"type":"(rubric_ignore|no_verify)"'; then
  exit 2
fi
exit 0
