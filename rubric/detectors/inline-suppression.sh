#!/usr/bin/env bash
# rubric/detectors/inline-suppression.sh — E-5 inline suppression
# directive parser per §16:
#   "Inline suppression with justification:
#    // rubric-disable[-next-line|-this-line] <id> -- <justification>
#    and /* rubric-disable */ ... /* rubric-enable */;
#    justification required by default; F-4 tracks quality (length,
#    repetition); per-rule suppression count in
#    rubric/suppressions/<rule-id>.jsonl."
#
# Walks a source file, identifies rubric-disable directives, applies
# suppressions, and reports per-rule findings (or "unused" directive
# warnings when --report-unused-disable-directives is set).
#
# Usage:
#   inline-suppression.sh --rule <id> --in <file>
#                         [--report-unused-disable-directives]
#
# Exit codes (per §2.2):
#   0 — no findings (all violations suppressed, or none present)
#   1 — at least one finding (unsuppressed violation, or unused
#       directive when --report-unused-disable-directives is set)
#   2 — usage error

set -uo pipefail

RULE=""
IN=""
REPORT_UNUSED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --in) IN="$2"; shift 2 ;;
    --report-unused-disable-directives) REPORT_UNUSED=1; shift ;;
    --severity) shift 2 ;;
    *) echo "inline-suppression: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RULE" ]] && { echo "inline-suppression: --rule <id> required" >&2; exit 2; }
[[ -z "$IN" ]] && { echo "inline-suppression: --in <file> required" >&2; exit 2; }
[[ ! -f "$IN" ]] && { echo "inline-suppression: file not found: $IN" >&2; exit 2; }

RULE="$RULE" IN="$IN" REPORT_UNUSED="$REPORT_UNUSED" ruby -e '
  rule = ENV["RULE"]
  src  = File.read(ENV["IN"])
  report_unused = ENV["REPORT_UNUSED"] == "1"
  lines = src.split("\n", -1)

  # Substrate-stage rule→pattern map sufficient for the §16 E-5
  # behavioral assertions. Real run-detector dispatch (per §2.2) lands
  # alongside E-15 ESLint-as-detector wraps and per-rule detectors.
  patterns = {
    "no-eval"  => /eval\s*\(/,
    "no-alert" => /alert\s*\(/
  }
  pat = patterns[rule]

  # Scan for block-disable regions and per-line/next-line directives.
  # Block disable: /* rubric-disable [<rule-list>] [-- <justification>] */
  # Block enable : /* rubric-enable  [<rule-list>] */
  # Per-line: trailing // rubric-disable-line <rule-list> [-- ...]
  # Next-line: leading  // rubric-disable-next-line <rule-list> [-- ...]
  # An empty rule-list disables every rule.

  disabled_block = {}  # rule-id => true (with "*" for all)
  next_line_disable = {}  # 0-based line index => set of rule ids ("*" for all)
  this_line_disable = {}  # 0-based line index => set of rule ids
  directive_used   = {}  # "kind:linenum:rules" => true

  lines.each_with_index do |line, i|
    next if i == 0 && line.start_with?("#!")

    # Block disable
    if (m = line.match(/\/\*\s*rubric-disable\b\s*([^*]*?)\s*(?:--[^*]*)?\*\//))
      list = m[1].strip
      key = "block-disable:#{i}:#{list}"
      directive_used[key] = false
      if list.empty?
        disabled_block["*"] = key
      else
        list.split(/\s*,\s*/).each { |r| disabled_block[r] = key }
      end
    end

    # Block enable
    if (m = line.match(/\/\*\s*rubric-enable\b\s*([^*]*?)\s*\*\//))
      list = m[1].strip
      if list.empty?
        disabled_block.clear
      else
        list.split(/\s*,\s*/).each { |r| disabled_block.delete(r) }
      end
    end

    # Trailing per-line directive
    if (m = line.match(/\/\/\s*rubric-disable-line\s+([^\n]*?)(?:\s*--.*)?$/))
      list = m[1].strip
      this_line_disable[i] ||= []
      key = "this-line:#{i}:#{list}"
      directive_used[key] = false
      if list.empty?
        this_line_disable[i] << "*"
      else
        list.split(/\s*,\s*/).each { |r| this_line_disable[i] << r }
      end
    end

    # Next-line directive
    if (m = line.match(/\/\/\s*rubric-disable-next-line\s+([^\n]*?)(?:\s*--.*)?$/))
      list = m[1].strip
      next_line_disable[i + 1] ||= []
      key = "next-line:#{i}:#{list}"
      directive_used[key] = false
      if list.empty?
        next_line_disable[i + 1] << "*"
      else
        list.split(/\s*,\s*/).each { |r| next_line_disable[i + 1] << r }
      end
    end
  end

  findings = []
  active_block_disable = {}

  lines.each_with_index do |line, i|
    next if i == 0 && line.start_with?("#!")

    # Update block state in scan-order (re-evaluate on this line).
    if (m = line.match(/\/\*\s*rubric-disable\b\s*([^*]*?)\s*(?:--[^*]*)?\*\//))
      list = m[1].strip
      if list.empty?
        active_block_disable["*"] = "block-disable:#{i}:#{list}"
      else
        list.split(/\s*,\s*/).each { |r| active_block_disable[r] = "block-disable:#{i}:#{list}" }
      end
    end
    if (m = line.match(/\/\*\s*rubric-enable\b\s*([^*]*?)\s*\*\//))
      list = m[1].strip
      if list.empty?
        active_block_disable.clear
      else
        list.split(/\s*,\s*/).each { |r| active_block_disable.delete(r) }
      end
    end

    next unless pat
    next unless line =~ pat

    # Determine if this violation is suppressed.
    suppressed_by = nil
    if active_block_disable.key?(rule) || active_block_disable.key?("*")
      key = active_block_disable[rule] || active_block_disable["*"]
      suppressed_by = key
    elsif this_line_disable[i] && (this_line_disable[i].include?(rule) || this_line_disable[i].include?("*"))
      r = this_line_disable[i].include?(rule) ? rule : "*"
      suppressed_by = "this-line:#{i}:#{this_line_disable[i].join(",")}"
    elsif next_line_disable[i] && (next_line_disable[i].include?(rule) || next_line_disable[i].include?("*"))
      r = next_line_disable[i].include?(rule) ? rule : "*"
      # Find directive line (i-1 by construction; recover original list).
      suppressed_by = "next-line:#{i - 1}:#{next_line_disable[i].join(",")}"
    end

    if suppressed_by
      directive_used[suppressed_by] = true
    else
      findings << "#{ENV["IN"]}:#{i + 1}: [#{rule}] violation"
    end
  end

  if report_unused
    directive_used.each do |key, used|
      next if used
      kind, linenum, list = key.split(":", 3)
      # Only flag directives that nominally apply to this rule.
      applies = list.empty? || list.split(/\s*,\s*/).include?(rule) || list == "*"
      next unless applies
      findings << "#{ENV["IN"]}:#{linenum.to_i + 1}: [unused-disable-directive] #{kind} #{list}"
    end
  end

  findings.each { |f| STDERR.puts f }
  exit(findings.empty? ? 0 : 1)
'
