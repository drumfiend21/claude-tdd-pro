#!/usr/bin/env bash
# validate-all — composes G-6 (validate-source-file) across the
# generated-code-quality-standards/ tree per §17 G-12.
#
# Per §17 G-12 verbatim:
#   "Validation: generated-code-quality-standards/validate-all.sh runs in
#    /doctor and CI (H-11). Failures: file's rules excluded from aggregation
#    until fixed; --allow-invalid-source-folder bypass logged."
#
# Per detector contract §2.2:
#   exit 0 → all files validated successfully
#   exit 1 → some files failed validation (errors written to stderr)
#   exit 2 → tooling/usage error (no source files found, --root missing)
#
# Flags:
#   --root <dir>                       root of the source-folder tree
#   --format <text|json>               summary format (default text)
#   --check-cross-file-collisions      reject when same rule id appears in two files
#   --check-empty-namespaces           reject when a non-substrate namespace folder has no .yaml files
#
# Skipped during walk:
#   - any folder named _meta (substrate)
#   - any folder named _archived anywhere in the path (archived files)

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
ROOT=""
FORMAT="text"
CHECK_CROSS_FILE_COLLISIONS=0
CHECK_EMPTY_NAMESPACES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --check-cross-file-collisions) CHECK_CROSS_FILE_COLLISIONS=1; shift ;;
    --check-empty-namespaces) CHECK_EMPTY_NAMESPACES=1; shift ;;
    -h|--help) sed -n '1,30p' "$0" | grep -E '^# ' | sed 's/^# //'; exit 0 ;;
    *) echo "validate-all: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$ROOT" ]] && { echo "validate-all: --root <path> required" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "validate-all: --root not a directory: $ROOT" >&2; exit 2; }

VALIDATE_SOURCE_FILE="$PLUGIN_ROOT/rubric/detectors/validate-source-file.sh"
[[ ! -x "$VALIDATE_SOURCE_FILE" && ! -f "$VALIDATE_SOURCE_FILE" ]] && {
  echo "validate-all: validate-source-file.sh missing at $VALIDATE_SOURCE_FILE" >&2; exit 2;
}

# Collect source files: any *.yaml under <root> at depth >=2 (i.e. inside a namespace folder),
# excluding paths containing /_meta/ or /_archived/.
# Portable to bash 3.2 (macOS) — no mapfile.
FILES=()
FILES_TOTAL=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  FILES+=("$f")
  FILES_TOTAL=$((FILES_TOTAL+1))
done < <(find "$ROOT" -mindepth 2 -name "*.yaml" -type f 2>/dev/null \
  | grep -v -E "(^|/)_meta/|(^|/)_archived/" \
  | sort)

if [[ "$FILES_TOTAL" -eq 0 ]]; then
  echo "validate-all: no source files found under $ROOT" >&2
  exit 2
fi

PASSED=0; FAILED=0
FAILED_FILES=()
for f in "${FILES[@]}"; do
  if bash "$VALIDATE_SOURCE_FILE" "$f" >/dev/null 2>&1; then
    PASSED=$((PASSED+1))
  else
    FAILED=$((FAILED+1))
    FAILED_FILES+=("$f")
  fi
done

# Cross-file collision check
COLLISION_FAIL=0
if [[ "$CHECK_CROSS_FILE_COLLISIONS" -eq 1 ]] && command -v ruby >/dev/null 2>&1; then
  COLLISION_OUTPUT=$(ruby -ryaml -e '
    seen = {}
    collisions = []
    ARGV.each do |path|
      doc = begin; YAML.load_file(path); rescue; nil; end
      next unless doc.is_a?(Hash) && doc["rules"].is_a?(Array)
      doc["rules"].each do |r|
        next unless r.is_a?(Hash) && r["id"].is_a?(String)
        id = r["id"]
        if seen.key?(id)
          collisions << [id, seen[id], path]
        else
          seen[id] = path
        end
      end
    end
    collisions.each { |id, p1, p2| STDERR.puts "duplicate rule id: #{id} appears in #{p1} and #{p2}" }
    exit collisions.empty? ? 0 : 1
  ' "${FILES[@]}" 2>&1) || COLLISION_FAIL=1
  [[ -n "$COLLISION_OUTPUT" ]] && echo "$COLLISION_OUTPUT" >&2
fi

# Empty namespace check (non-substrate namespaces only)
EMPTY_NS_FAIL=0
if [[ "$CHECK_EMPTY_NAMESPACES" -eq 1 ]]; then
  for ns_dir in "$ROOT"/*/; do
    [[ -d "$ns_dir" ]] || continue
    ns_name=$(basename "$ns_dir")
    [[ "$ns_name" == "_meta" || "$ns_name" == "_archived" ]] && continue
    yaml_count=$(find "$ns_dir" -maxdepth 1 -name "*.yaml" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$yaml_count" -eq 0 ]]; then
      echo "namespace folder is empty (no .yaml files): $ns_name" >&2
      EMPTY_NS_FAIL=1
    fi
  done
fi

# Summary output (always to stderr per project convention; spec assertions read 2>out.txt)
if [[ "$FORMAT" == "json" ]]; then
  echo "{\"files_total\":${#FILES[@]},\"files_passed\":$PASSED,\"files_failed\":$FAILED,\"files_excluded_from_aggregation\":$FAILED}" >&2
else
  echo "${#FILES[@]} files validated" >&2
  echo "passed: $PASSED" >&2
  echo "failed: $FAILED" >&2
  for ff in "${FAILED_FILES[@]:-}"; do
    [[ -n "$ff" ]] && echo "  failed: $ff" >&2
  done
fi

# Exit-code discipline: text mode (CI gate path) exits 1 on any failure;
# JSON mode (data-output path) exits 0 always — the summary itself tells
# the consumer about failures (files_failed > 0).
if [[ "$FORMAT" == "json" ]]; then
  exit 0
fi
if [[ $FAILED -gt 0 || $COLLISION_FAIL -eq 1 || $EMPTY_NS_FAIL -eq 1 ]]; then
  exit 1
fi
exit 0
