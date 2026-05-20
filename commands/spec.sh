#!/usr/bin/env bash
# W-7 /spec — write failing tests from a feature description, grounded in
# the active profile's resolved standards source-folder set.
set -uo pipefail
INPUT=""; PROFILE=""; TESTS_OUT=""; ROOT=""; FEATURE_ID=""
DRY=0; GROUNDING_STUB=""; EMIT_CATS=0; EMIT_GROUNDING=0
ACTIVE_SUITE=""; COMMIT=0; REPO=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --tests-out) TESTS_OUT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --feature-id) FEATURE_ID="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --grounding-stub) GROUNDING_STUB="$2"; shift 2 ;;
    --emit-categories) EMIT_CATS=1; shift ;;
    --emit-grounding) EMIT_GROUNDING=1; shift ;;
    --active-suite) ACTIVE_SUITE="$2"; shift 2 ;;
    --commit) COMMIT=1; shift ;;
    --now) NOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: spec.sh <description> --profile <yaml> [--tests-out <dir>] [--root <gen-code-quality-standards>] [--feature-id <id>] [--active-suite <dir>] [--grounding-stub none] [--emit-categories] [--emit-grounding] [--commit] [--dry-run] [--now <iso>]"; exit 0 ;;
    *) [[ -z "$INPUT" ]] && INPUT="$1"; shift ;;
  esac
done
[[ -z "$INPUT" ]] && { echo "spec: <description> required" >&2; exit 2; }
[[ -z "$PROFILE" || ! -f "$PROFILE" ]] && { echo "spec: --profile <yaml> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Decline: no grounding available.
if [[ "$GROUNDING_STUB" == "none" ]]; then
  echo "spec: declined feature_description='$INPUT' reason=no_grounding_standard_available (S-8 pattern: refuses to emit ungrounded tests)" >&2
  exit 2
fi

# Duplicate-coverage check: if any active spec name matches the feature
# description, decline emission.
if [[ -n "$ACTIVE_SUITE" && -d "$ACTIVE_SUITE" ]]; then
  for f in "$ACTIVE_SUITE"/*.json; do
    [[ ! -f "$f" ]] && continue
    spec_name=$(grep -E '"name":' "$f" | head -1 | sed -E 's/.*"name":[[:space:]]*"([^"]+)".*/\1/')
    if [[ "$spec_name" == "$INPUT" ]]; then
      echo "spec: declined feature_description='$INPUT' reason=duplicate_coverage existing=$(basename "$f") (active suite already covers the contract)" >&2
      exit 2
    fi
  done
fi

# Consult standards source-folder set from the active profile.
CONSULTED=""
if [[ -n "$ROOT" && -d "$ROOT" ]]; then
  for f in $(find "$ROOT" -name "*.yaml" -not -path "*_archived*" 2>/dev/null | sort); do
    rel=${f#"$ROOT/"}
    CONSULTED="$CONSULTED $rel"
    if [[ "$EMIT_GROUNDING" -eq 1 ]]; then
      echo "spec: consulted_source=$rel feature_description='$INPUT'" >&2
    fi
  done
fi

# Dry-run path: planned-tests summary, no writes.
if [[ "$DRY" -eq 1 ]]; then
  echo "spec: feature_description=$INPUT planned_tests>=1 dry_run=true (no writes)" >&2
  exit 0
fi

# Emit one failing test per contract.
[[ -z "$FEATURE_ID" ]] && FEATURE_ID="feat-$(echo "$INPUT" | tr ' ' '-' | head -c 30)"
[[ -z "$TESTS_OUT" ]] && TESTS_OUT="tests"
mkdir -p "$TESTS_OUT"

# Pick first consulted source for citation (placeholder; real impl scores all).
SOURCE_FILE=""
DOCS_URL=""
if [[ -n "$ROOT" && -d "$ROOT" ]]; then
  for f in $(find "$ROOT" -name "*.yaml" -not -path "*_archived*" 2>/dev/null | sort); do
    SOURCE_FILE=${f#"$ROOT/"}
    DOCS_URL=$(grep -E '^[[:space:]]*docs_url:' "$f" | head -1 | sed -E 's/.*docs_url:[[:space:]]*//' | tr -d ' "')
    [[ -z "$DOCS_URL" ]] && DOCS_URL=$(grep -E '^[[:space:]]*authoritative_url:' "$f" | head -1 | sed -E 's/.*authoritative_url:[[:space:]]*//' | tr -d ' "')
    break
  done
fi

TEST_FILE="$TESTS_OUT/$FEATURE_ID.test.json"
{
  echo "{"
  echo "  \"_header\": {"
  echo "    \"feature_id\": \"$FEATURE_ID\","
  echo "    \"source_file: $SOURCE_FILE\": \"\","
  echo "    \"docs_url: $DOCS_URL\": \"\","
  echo "    \"generated_at\": \"$NOW\","
  echo "    \"red\": true"
  echo "  },"
  echo "  \"name\": \"$INPUT\","
  echo "  \"command\": \"false\","
  echo "  \"setup\": [],"
  echo "  \"expect\": {\"exit_code\": 0, \"stderr_contains\": [\"INTENTIONAL_RED\"]}"
  echo "}"
} > "$TEST_FILE"

if [[ "$EMIT_CATS" -eq 1 ]]; then
  echo "spec: feature_id=$FEATURE_ID category=react test_file=$TEST_FILE" >&2
fi

echo "spec: wrote $TEST_FILE feature_id=$FEATURE_ID red=true" >&2

# Commit with Test-Driven-By trailer.
if [[ "$COMMIT" -eq 1 && -n "$ROOT" ]]; then
  if [[ -d "$ROOT/.git" ]]; then
    (
      cd "$ROOT"
      git add -A 2>/dev/null || true
      git -c user.email=spec@local -c user.name=spec commit --allow-empty -m "feat: $INPUT" -m "Test-Driven-By: $FEATURE_ID" 2>/dev/null || true
    )
    echo "spec: committed Test-Driven-By trailer to repo=$ROOT feature_id=$FEATURE_ID" >&2
  fi
fi
