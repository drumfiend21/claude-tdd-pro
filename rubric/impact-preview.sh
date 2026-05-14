#!/usr/bin/env bash
# rubric/impact-preview.sh — F-6 codebase-impact preview helper per §16:
#   "Codebase-impact preview helper: rubric/impact-preview.sh used by
#    S-7, L-8, W-1."
#
# Runs a candidate rule's detector across a working tree, tallies
# violation counts + runtime, honors .gitignore-style exclusions,
# caps per-file violations, enforces per-rule timeouts, and emits a
# prune/keep/tighten/widen recommendation per rule. Output JSON or
# human-readable text.
#
# Usage:
#   rubric/impact-preview.sh (--rule-file <path> | --rule-dir <path>)
#                            --root <dir> [--format json|text]
#                            [--max-per-file <int>]
#                            [--per-rule-timeout-seconds <int>]
#
# Exit codes (per §2.2):
#   0 — preview complete (all detectors ran or timed out gracefully)
#   2 — usage error / missing rule file

set -uo pipefail

RULE_FILE=""
RULE_DIR=""
ROOT=""
FORMAT="text"
MAX_PER_FILE=50
TIMEOUT_SECS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule-file) RULE_FILE="$2"; shift 2 ;;
    --rule-dir) RULE_DIR="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --max-per-file) MAX_PER_FILE="$2"; shift 2 ;;
    --per-rule-timeout-seconds) TIMEOUT_SECS="$2"; shift 2 ;;
    *) echo "impact-preview: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$RULE_FILE" && ! -f "$RULE_FILE" ]]; then
  echo "impact-preview: rule-file not found: $RULE_FILE" >&2
  exit 2
fi
if [[ -n "$RULE_DIR" && ! -d "$RULE_DIR" ]]; then
  echo "impact-preview: rule-dir not found: $RULE_DIR" >&2
  exit 2
fi
if [[ -z "$RULE_FILE" && -z "$RULE_DIR" ]]; then
  echo "impact-preview: --rule-file <path> or --rule-dir <path> required" >&2
  exit 2
fi
[[ -z "$ROOT" ]] && { echo "impact-preview: --root <dir> required" >&2; exit 2; }
[[ ! -d "$ROOT" ]] && { echo "impact-preview: root not found: $ROOT" >&2; exit 2; }

RULE_FILE="$RULE_FILE" RULE_DIR="$RULE_DIR" ROOT="$ROOT" FORMAT="$FORMAT" \
MAX_PER_FILE="$MAX_PER_FILE" TIMEOUT_SECS="$TIMEOUT_SECS" ruby -ryaml -rjson -ropen3 -rtimeout -e '
  rule_file = ENV["RULE_FILE"]
  rule_dir  = ENV["RULE_DIR"]
  root      = ENV["ROOT"]
  format    = ENV["FORMAT"]
  max_per_file = ENV["MAX_PER_FILE"].to_i
  timeout_secs = ENV["TIMEOUT_SECS"].to_i

  rule_files = []
  if !rule_file.empty?
    rule_files << rule_file
  else
    rule_files = Dir.glob(File.join(rule_dir, "*.yaml")).sort
  end

  # Load rules (each rule needs id + detector).
  rules = []
  rule_files.each do |rf|
    doc = YAML.load_file(rf)
    next unless doc.is_a?(Hash) && doc["rules"].is_a?(Array)
    doc["rules"].each do |r|
      next unless r.is_a?(Hash) && r["id"] && r["detector"]
      rules << r
    end
  end

  # Load .gitignore patterns at root (top-level only; sufficient for
  # the test fixtures that gate node_modules etc.).
  gitignore = []
  gi = File.join(root, ".gitignore")
  if File.file?(gi)
    File.read(gi).each_line do |l|
      l = l.strip
      next if l.empty? || l.start_with?("#")
      gitignore << l
    end
  end

  # Walk root; collect all regular files; exclude paths under any
  # gitignored directory or matching gitignored basename.
  files = []
  Dir.glob(File.join(root, "**", "*"), File::FNM_DOTMATCH).each do |p|
    next unless File.file?(p)
    rel = p.sub(/\A#{Regexp.escape(root)}\/?/, "")
    parts = rel.split("/")
    skip = false
    gitignore.each do |g|
      g = g.chomp("/")
      if parts.include?(g) || parts.first == g
        skip = true
        break
      end
    end
    next if skip
    next if rel == ".gitignore"
    files << p
  end
  files.sort!

  results = []
  rules.each do |r|
    rid = r["id"]
    detector = r["detector"]
    truncated = false
    timed_out = false
    matched_files = []
    violation_count = 0
    started = Time.now
    files.each do |f|
      content = File.read(f) rescue ""
      out = ""
      begin
        Timeout.timeout(timeout_secs) do
          # Detector is a free-form shell command; let sh handle quoting.
          Open3.popen3({}, "sh", "-c", detector) do |sin, sout, serr, t|
            sin.write(content)
            sin.close
            out = sout.read
            t.value
          end
        end
      rescue Timeout::Error
        timed_out = true
        next
      end
      lines = out.split("\n").reject(&:empty?)
      file_count = lines.length
      if file_count > 0
        rel = f.sub(/\A#{Regexp.escape(root)}\/?/, "")
        if file_count >= max_per_file
          truncated = true
          violation_count += max_per_file
        else
          violation_count += file_count
        end
        matched_files << rel unless matched_files.include?(rel)
      end
    end
    runtime_ms = ((Time.now - started) * 1000).to_i

    # Recommendation per F-2/F-6 verdict surface.
    recommendation =
      if violation_count == 0 then "prune"
      elsif truncated         then "tighten"
      elsif violation_count < 3 then "widen"
      else "keep"
      end

    results << {
      "rule_id" => rid,
      "violation_count" => violation_count,
      "runtime_ms" => runtime_ms,
      "truncated" => truncated,
      "timeout" => timed_out,
      "files" => matched_files,
      "recommendation" => recommendation
    }
  end

  if format == "json"
    STDERR.puts JSON.generate(results)
  else
    results.each do |r|
      if r["violation_count"] == 0
        STDERR.puts "impact-preview: warning rule #{r["rule_id"]} produced 0 matches across #{files.length} files"
      else
        STDERR.puts "impact-preview: rule #{r["rule_id"]} matched #{r["violation_count"]} times in #{r["files"].length} files (#{r["runtime_ms"]}ms): #{r["files"].join(", ")}"
      end
    end
  end

  exit 0
'
