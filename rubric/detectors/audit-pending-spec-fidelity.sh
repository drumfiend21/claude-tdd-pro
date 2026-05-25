#!/usr/bin/env bash
# §2.25 / §25 pending-spec content fidelity auditor.
#
# Scans pending spec files for vocabulary (field names, YAML/JSON keys,
# substrate paths) that does not appear in the architecture section for
# the corresponding feature ID. Reports discrepancies as
#   unknown_vocab=<token> spec=<filename>:<line>
# and exits 1 when any are found, 0 when clean.
#
# CLI:
#   --pending PATH    pending-feature folder (required)
#                       e.g. evals/pending/CC/2-6-standards-source/
#   --arch PATH       architecture file (required)
#                       e.g. docs/architecture-v1.9.md
#   --section LABEL   architecture section label to constrain the lookup
#                     to (recommended). e.g. "§2.6" or "§11" or "§16"
#   --exempt-file PATH  optional newline-separated file of exempt tokens
#
# Exit codes:
#   0  no discrepancies (clean)
#   1  discrepancies found (blocks promotion)
#   2  usage error

PENDING=""
ARCH=""
SECTION=""
EXEMPT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pending)     PENDING="${2-}";     shift 2 ;;
    --arch)        ARCH="${2-}";        shift 2 ;;
    --section)     SECTION="${2-}";     shift 2 ;;
    --exempt-file) EXEMPT_FILE="${2-}"; shift 2 ;;
    -h|--help)
      echo "Usage: audit-pending-spec-fidelity.sh --pending <dir> --arch <file> [--section <label>] [--exempt-file <file>]" >&2
      exit 0
      ;;
    *) echo "audit-pending-spec-fidelity: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$PENDING" ] || [ -z "$ARCH" ]; then
  echo "audit-pending-spec-fidelity: --pending and --arch required" >&2
  exit 2
fi
if [ ! -d "$PENDING" ]; then
  echo "audit-pending-spec-fidelity: --pending not a directory: $PENDING" >&2
  exit 2
fi
if [ ! -f "$ARCH" ]; then
  echo "audit-pending-spec-fidelity: --arch not a file: $ARCH" >&2
  exit 2
fi

PENDING_DIR="$PENDING" ARCH_FILE="$ARCH" SECTION_LABEL="$SECTION" EXEMPT_PATH="$EXEMPT_FILE" ruby - <<'RUBY'
require 'json'
require 'set'

pending_dir = ENV['PENDING_DIR'].to_s
arch_file   = ENV['ARCH_FILE'].to_s
section     = ENV['SECTION_LABEL'].to_s
exempt_path = ENV['EXEMPT_PATH'].to_s

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Build the architecture vocabulary set for the constrained section.
arch_text = File.read(arch_file, encoding: 'UTF-8')

if section.empty?
  arch_window = arch_text
else
  # Find the section heading and slurp until the next heading of the
  # same or higher depth. Sections like §2.X live under ### headings;
  # phases like §11 live under ## headings.
  section_utf8 = section.dup.force_encoding('UTF-8')
  esc = Regexp.escape(section_utf8)
  re_start = Regexp.new("^(\#+)\\s+#{esc}[^\\n]*\\n", Regexp::MULTILINE)
  start_match = arch_text.match(re_start)
  if start_match
    start_idx = start_match.pre_match.length + start_match[0].length
    depth     = start_match[1].length
    rest      = arch_text[start_idx..]
    # Match next heading of same-or-shallower depth.
    re_next = Regexp.new("^\#{1,#{depth}}\\s+\\S", Regexp::MULTILINE)
    next_match = rest.match(re_next)
    end_idx = next_match ? next_match.pre_match.length : rest.length
    arch_window = rest[0, end_idx]
  else
    STDERR.write("audit-pending-spec-fidelity: section #{section} not found in #{arch_file}\n")
    exit 2
  end
end

# Extract architecture vocabulary: words inside backticks, words on
# field-list lines, and YAML/JSON keys in fenced blocks.
arch_vocab = Set.new

# Backticked tokens
arch_window.scan(/`([a-zA-Z][a-zA-Z0-9_.\/:\-]*)`/) do |m|
  arch_vocab << m[0].downcase
end
# Words in fenced code blocks
arch_window.scan(/```[a-z]*\n(.*?)```/m) do |m|
  m[0].scan(/[a-zA-Z][a-zA-Z0-9_]*/) { |w| arch_vocab << w.downcase }
end
# YAML/JSON keys outside fenced blocks: <word>:
arch_window.scan(/^\s*([a-zA-Z][a-zA-Z0-9_]*)\s*:/m) do |m|
  arch_vocab << m[0].downcase
end
# Inline `<word>` mentions
arch_window.scan(/\b([a-z][a-z0-9_]{2,})\b/) do |m|
  arch_vocab << m[0].downcase
end

# Exempt set: CLI flags, common English, fixture noise.
EXEMPT_BUILTIN = %w[
  ok blocked fail pass true false null nil yes no
  bash echo printf grep cat node ruby python find
  exit exit_code expect setup command name file path
  src tmp tmpdir mkdir test tests dir
  setup_file stderr stdout stdin
  process http https example com
  the and not for from with into into within when then else
  hash sha256 sha512 md5
  json yaml yml md html xml
  array map list object string number boolean integer float
  http_status status
  if rc cmd
].to_set

exempt_user = Set.new
if !exempt_path.empty? && File.exist?(exempt_path)
  File.read(exempt_path).each_line { |ln| exempt_user << ln.strip.downcase }
end

def exempt?(token, builtin, user)
  return true if token.length < 3
  return true if token =~ /\A\d+\z/
  return true if token.start_with?('--')
  return true if builtin.include?(token)
  return true if user.include?(token)
  false
end

# Walk pending specs
specs = Dir.glob(File.join(pending_dir, "*.json"))
if specs.empty?
  STDERR.write("audit-pending-spec-fidelity: no specs in #{pending_dir}\n")
  exit 2
end

unknowns = []

specs.each do |spec_path|
  begin
    d = JSON.parse(File.read(spec_path))
  rescue => e
    STDERR.write("audit-pending-spec-fidelity: parse error in #{spec_path}: #{e.message}\n")
    next
  end
  haystack = ((d['setup'] || []).join("\n") + "\n" + d['command'].to_s)
  spec_base = File.basename(spec_path)
  # Extract YAML/JSON keys appearing in haystack: "<word>:" with no
  # preceding alphanumeric (to avoid URLs like "https://").
  haystack.scan(/(?:^|[\s\\"\{\[,])([a-z][a-z0-9_]+):/m) do |m|
    tok = m[0].downcase
    next if exempt?(tok, EXEMPT_BUILTIN, exempt_user)
    next if arch_vocab.include?(tok)
    unknowns << "unknown_vocab=#{tok} spec=#{spec_base}"
  end
end

# Deduplicate while preserving first-seen order.
seen = {}
deduped = []
unknowns.each do |u|
  next if seen[u]
  seen[u] = true
  deduped << u
end

if deduped.empty?
  STDERR.write("fidelity_audit=clean pending=#{pending_dir} section=#{section}\n")
  STDERR.write("specs_audited=#{specs.size}\n")
  exit 0
else
  deduped.each { |u| STDERR.write("#{u}\n") }
  STDERR.write("fidelity_audit=dirty pending=#{pending_dir} section=#{section} unknown_count=#{deduped.size}\n")
  exit 1
end
RUBY
