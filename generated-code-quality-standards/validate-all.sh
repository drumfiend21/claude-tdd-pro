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
CHECK_ID_NAMESPACING=0
EMIT_ID_LOCATIONS=0
CHECK_REPLACED_BY_REFERENCES=0
INCLUDE_RULES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --check-cross-file-collisions) CHECK_CROSS_FILE_COLLISIONS=1; shift ;;
    --check-empty-namespaces) CHECK_EMPTY_NAMESPACES=1; shift ;;
    --check-id-namespacing) CHECK_ID_NAMESPACING=1; shift ;;
    --emit-id-locations) EMIT_ID_LOCATIONS=1; shift ;;
    --check-replaced-by-references) CHECK_REPLACED_BY_REFERENCES=1; shift ;;
    --include-rules) INCLUDE_RULES=1; shift ;;
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

# G-1: reject unknown top-level folders. Operator-added namespaces live under
# _operator/<my-org>/, community plugins under _community/<plugin-id>/. Any
# other unrecognized top-level folder is an authoring error.
KNOWN_NAMESPACES=(google us-government european-union finance-industry owasp w3c web-vitals react node typescript slsa linux-foundation industry-self-regulatory aws azure gcp hashicorp security-governance documentation _universal _operator _community _meta)
for ns_dir in "$ROOT"/*/; do
  [[ -d "$ns_dir" ]] || continue
  ns_name=$(basename "$ns_dir")
  is_known=0
  for known in "${KNOWN_NAMESPACES[@]}"; do
    [[ "$ns_name" == "$known" ]] && { is_known=1; break; }
  done
  if [[ "$is_known" -eq 0 ]]; then
    echo "validate-all: unknown top-level folder: $ns_name (not in 14 defaults + _operator/_community/_meta substrate)" >&2
    exit 2
  fi
done

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
      doc = begin; YAML.unsafe_load_file(path); rescue; nil; end
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

# G-3 rule-id namespacing check: enforce per-folder prefix discipline per
# §16 G-3 verbatim. Default folders use "g-" (not "g-universal-"),
# _universal/ uses "g-universal-", _operator/<my-org>/ uses "<my-org>-",
# _community/<plugin-id>/ uses "<plugin-id>/<rule-id>" namespaced form.
# Rule IDs must match ^[a-z][a-z0-9-]*(/[a-z][a-z0-9-]*)?$ (lowercase
# kebab; optional plugin/ namespace).
NAMESPACING_FAIL=0
if [[ "$CHECK_ID_NAMESPACING" -eq 1 ]] && command -v ruby >/dev/null 2>&1; then
  ROOT_ABS=$(cd "$ROOT" && pwd)
  ROOT_ABS="$ROOT_ABS" ruby -ryaml -e '
    root = ENV["ROOT_ABS"]
    pattern = /\A[a-z][a-z0-9-]*(\/[a-z][a-z0-9-]*)?\z/
    fail_count = 0
    ARGV.each do |path|
      doc = begin; YAML.unsafe_load_file(path); rescue; nil; end
      next unless doc.is_a?(Hash) && doc["rules"].is_a?(Array)
      rel = path.sub(/\A#{Regexp.escape(root)}\/?/, "")
      parts = rel.split("/")
      ns = parts.first
      doc["rules"].each do |r|
        next unless r.is_a?(Hash) && r["id"].is_a?(String)
        id = r["id"]
        unless id =~ pattern
          STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: must match kebab-case pattern ^[a-z][a-z0-9-]*(/[a-z][a-z0-9-]*)?$"
          fail_count += 1
          next
        end
        if ns == "_universal"
          unless id.start_with?("g-universal-")
            STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: rules under _universal/ must use g-universal- prefix"
            fail_count += 1
          end
        elsif ns == "_operator"
          org = parts[1]
          unless org && id.start_with?("#{org}-")
            STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: rules under _operator/#{org}/ must start with #{org}- prefix"
            fail_count += 1
          end
        elsif ns == "_community"
          plugin = parts[1]
          unless plugin && id.start_with?("#{plugin}/")
            STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: rules under _community/#{plugin}/ must use #{plugin}/<rule-id> namespaced form"
            fail_count += 1
          end
        else
          # Default plugin-shipped namespace folder.
          if id.start_with?("g-universal-")
            STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: g-universal- prefix is reserved for _universal/ folder"
            fail_count += 1
          elsif !id.start_with?("g-")
            STDERR.puts "id-namespacing: rule id \"#{id}\" in #{rel}: plugin-shipped rules must start with g- prefix"
            fail_count += 1
          end
        end
      end
    end
    exit(fail_count > 0 ? 2 : 0)
  ' "${FILES[@]}" || NAMESPACING_FAIL=$?
fi
if [[ "$NAMESPACING_FAIL" -ne 0 ]]; then
  exit 2
fi

# G-3 emit-id-locations: emit per-rule {id => relative_path} map so callers
# can verify ID stability across file moves.
if [[ "$EMIT_ID_LOCATIONS" -eq 1 ]] && command -v ruby >/dev/null 2>&1; then
  ROOT_ABS=$(cd "$ROOT" && pwd)
  ROOT_ABS="$ROOT_ABS" ruby -ryaml -rjson -e '
    root = ENV["ROOT_ABS"]
    out = {}
    ARGV.each do |path|
      doc = begin; YAML.unsafe_load_file(path); rescue; nil; end
      next unless doc.is_a?(Hash) && doc["rules"].is_a?(Array)
      rel = path.sub(/\A#{Regexp.escape(root)}\/?/, "")
      doc["rules"].each do |r|
        next unless r.is_a?(Hash) && r["id"].is_a?(String)
        out[r["id"]] = rel
      end
    end
    STDERR.puts JSON.generate(out)
  ' "${FILES[@]}"
fi

# G-3 check-replaced-by-references: validate that deprecated rules'
# replaced_by entries point to ids present in the active rule set.
if [[ "$CHECK_REPLACED_BY_REFERENCES" -eq 1 ]] && command -v ruby >/dev/null 2>&1; then
  ROOT_ABS=$(cd "$ROOT" && pwd)
  REPLACED_BY_FAIL=$(ROOT_ABS="$ROOT_ABS" ruby -ryaml -e '
    seen = {}
    refs = []
    ARGV.each do |path|
      content = File.read(path)
      doc = begin; YAML.unsafe_load_file(path); rescue; nil; end
      if doc.is_a?(Hash) && doc["rules"].is_a?(Array)
        doc["rules"].each do |r|
          next unless r.is_a?(Hash) && r["id"].is_a?(String)
          seen[r["id"]] = true
          if r["replaced_by"].is_a?(Array)
            r["replaced_by"].each { |rb| refs << [rb, r["id"], path] if rb.is_a?(String) }
          end
        end
      else
        # Regex fallback for flow-style YAML with bare URLs.
        content.scan(/\bid:\s*([a-zA-Z0-9_\/-]+)/) { |m| seen[m[0]] = true }
        content.scan(/\bid:\s*([a-zA-Z0-9_\/-]+)[^}\n]*\breplaced_by:\s*\[([^\]]*)\]/) do |rid, body|
          body.split(",").each do |s|
            s = s.strip
            next if s.empty?
            refs << [s, rid, path]
          end
        end
      end
    end
    dangling = refs.reject { |rb, _, _| seen[rb] }
    dangling.each { |rb, src, p| STDERR.puts "replaced_by: rule \"#{src}\" replaced_by [\"#{rb}\"] dangling - \"#{rb}\" not present in active rule set" }
    exit(dangling.empty? ? 0 : 2)
  ' "${FILES[@]}" 2>&1) && REPLACED_BY_RC=0 || REPLACED_BY_RC=$?
  [[ -n "$REPLACED_BY_FAIL" ]] && echo "$REPLACED_BY_FAIL" >&2
  [[ "$REPLACED_BY_RC" -ne 0 ]] && exit 2
fi

# G-3 include-rules: when --format json --include-rules, emit per-rule
# fields (id, deprecated, replaced_by) alongside the file summary so
# callers can assert on rule-level metadata in a single pass.
if [[ "$INCLUDE_RULES" -eq 1 && "$FORMAT" == "json" ]] && command -v ruby >/dev/null 2>&1; then
  ROOT_ABS=$(cd "$ROOT" && pwd)
  ROOT_ABS="$ROOT_ABS" ruby -ryaml -rjson -e '
    rules = []
    ARGV.each do |path|
      doc = begin; YAML.unsafe_load_file(path); rescue; nil; end
      next unless doc.is_a?(Hash) && doc["rules"].is_a?(Array)
      doc["rules"].each do |r|
        next unless r.is_a?(Hash) && r["id"].is_a?(String)
        rules << { "id" => r["id"], "deprecated" => r["deprecated"] == true, "replaced_by" => r["replaced_by"] || [] }
      end
    end
    STDERR.puts JSON.generate({ "rules" => rules })
  ' "${FILES[@]}"
fi

# Data-mode flags suppress the text-mode CI-gate exit. When the caller is
# asking for data (--emit-id-locations, --check-replaced-by-references,
# --include-rules, --check-id-namespacing), unrelated per-file shape
# failures shouldn't cause exit 1 - the namespacing/replaced-by checks
# already exit 2 above on their own violations, and the data emission
# above happened before this point.
DATA_MODE=0
[[ "$EMIT_ID_LOCATIONS" -eq 1 ]] && DATA_MODE=1
[[ "$CHECK_REPLACED_BY_REFERENCES" -eq 1 ]] && DATA_MODE=1
[[ "$INCLUDE_RULES" -eq 1 ]] && DATA_MODE=1
[[ "$CHECK_ID_NAMESPACING" -eq 1 ]] && DATA_MODE=1

# Summary output (always to stderr per project convention; spec assertions read 2>out.txt)
if [[ "$DATA_MODE" -eq 0 ]]; then
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
fi

# Exit-code discipline: text mode (CI gate path) exits 1 on any failure;
# JSON mode (data-output path) exits 0 always; data-mode exits 0 (the
# specific data-checks already exited 2 above on their own violations).
if [[ "$DATA_MODE" -eq 1 ]]; then
  exit 0
fi
if [[ "$FORMAT" == "json" ]]; then
  exit 0
fi
if [[ $FAILED -gt 0 || $COLLISION_FAIL -eq 1 || $EMPTY_NS_FAIL -eq 1 ]]; then
  exit 1
fi
exit 0
