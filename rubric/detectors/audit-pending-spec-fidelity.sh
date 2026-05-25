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
#   --section LABEL   OPTIONAL architecture section label to additionally
#                     show as context (e.g. "§2.6" or "§11"). When set,
#                     vocabulary first checked against the section, then
#                     fallback to whole-architecture (cross-section
#                     references like §2.1 schema fields appearing in
#                     a §2.9 spec are legitimate and should not flag).
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

# Default to whole-architecture vocabulary lookup. Cross-section
# references (e.g. a §2.9 spec referencing §2.1 rule schema fields like
# `controls` and `detector`) are legitimate. The --section flag is
# informational; the actual gate is whole-architecture.
arch_window = arch_text
if !section.empty?
  # Verify section exists; warn if not. Don't constrain the vocabulary
  # window — that would false-positive on cross-section references.
  section_utf8 = section.dup.force_encoding('UTF-8')
  esc = Regexp.escape(section_utf8)
  re_start = Regexp.new("^(\#+)\\s+#{esc}[^\\n]*\\n", Regexp::MULTILINE)
  unless arch_text.match(re_start)
    STDERR.write("audit-pending-spec-fidelity: WARNING section #{section} not found in #{arch_file}\n")
  end
end

# Extract architecture vocabulary: words inside backticks, words on
# field-list lines, and YAML/JSON keys in fenced blocks.
arch_vocab = Set.new

# Backticked tokens. Strip trailing punctuation (colon, comma, period,
# bracket) so `recommended_set:` in arch text matches `recommended_set`
# in a spec body's YAML key extraction.
arch_window.scan(/`([a-zA-Z][a-zA-Z0-9_.\/:\-]*)`/) do |m|
  tok = m[0].downcase.sub(/[:,.\]\}]+\z/, '')
  arch_vocab << tok
end
# Words in fenced code blocks
arch_window.scan(/```[a-z]*\n(.*?)```/m) do |m|
  m[0].scan(/[a-zA-Z][a-zA-Z0-9_]*/) { |w| arch_vocab << w.downcase }
end
# YAML/JSON keys outside fenced blocks: <word>:
arch_window.scan(/^\s*([a-zA-Z][a-zA-Z0-9_]*)\s*:/m) do |m|
  arch_vocab << m[0].downcase
end
# NOTE: deliberately do NOT also pull every lowercase word from prose —
# that would render the auditor toothless (any common-sounding invented
# field name appears as substring in prose somewhere). Vocabulary
# evidence must be code-shaped (backtick, fenced block, or YAML key).

# Exempt set: CLI flags, common English, fixture noise.
EXEMPT_BUILTIN = %w[
  ok blocked fail pass true false null nil yes no
  bash echo printf grep cat node ruby python find
  exit exit_code expect setup command name file path
  src tmp tmpdir mkdir test tests dir
  setup_file stderr stdout stdin
  process http https example com ftp file ssh git
  the and not for from with into into within when then else
  hash sha256 sha512 md5
  json yaml yml md html xml
  array map list object string number boolean integer float
  http_status status
  if rc cmd
  write writes wrote read reads emit emits would
  validates validate accepts rejects creates removes
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
  # Normalize JSON-encoded newlines and tabs so the field-key regex
  # doesn't false-positive on the `n` after `\n` (and similar escapes
  # embedded in spec setup strings).
  haystack = haystack.gsub(/\\[nrt]/, ' ')
  spec_base = File.basename(spec_path)
  # Extract YAML/JSON keys appearing in haystack: "<word>:" with no
  # preceding backslash (to avoid escape-sequence tails like \nfoo:)
  # and no preceding alphanumeric (to avoid URLs like "https://").
  # Exclude when preceded by `:` to avoid matching the value half of
  # compound identifiers like `reviewed_by:<reviewer>:<date>` where
  # `<reviewer>` is a test fixture name, not a vocabulary key.
  haystack.scan(/(?<![\\A-Za-z0-9_:])([a-z][a-z0-9_]+):/m) do |m|
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
