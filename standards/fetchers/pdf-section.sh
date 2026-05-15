#!/usr/bin/env bash
# standards/fetchers/pdf-section.sh — S-2 fetcher per §16:
# extracts a numbered section from a PDF (e.g. V14.3 from OWASP ASVS).
# Substrate-stage extraction is text-based (greps for the section
# label and adjacent body); a future CL will route through pdftotext
# for true PDF parsing. Output to stderr.
#
# Usage:
#   pdf-section.sh --in <pdf-file> --section <label>

set -uo pipefail

IN=""
SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    *) echo "pdf-section: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$IN" ]] && { echo "pdf-section: --in <file> required" >&2; exit 2; }
[[ -z "$SECTION" ]] && { echo "pdf-section: --section <label> required" >&2; exit 2; }
[[ ! -f "$IN" ]] && { echo "pdf-section: file not found: $IN" >&2; exit 2; }

# Substrate-stage: treat input as text. Find the section label line and
# emit until the next section label (one with similar numeric pattern)
# or end-of-file. Section labels look like V14.3, V14.4, etc.
SECTION="$SECTION" IN="$IN" ruby -e '
  section = ENV["SECTION"]
  text = File.read(ENV["IN"])
  lines = text.split("\n", -1)
  out = []
  in_section = false
  found = false
  prefix = section.split(/[.-]/).first  # e.g., "V14"
  lines.each do |line|
    if line.start_with?(section)
      in_section = true
      found = true
      out << line
      next
    end
    if in_section
      # Stop at the next sibling section label (same prefix, different number).
      if line =~ /\A#{Regexp.escape(prefix)}\.\d/
        in_section = false
        break
      end
      out << line
    end
  end
  unless found
    STDERR.puts "pdf-section: section \"#{section}\" not found in #{ENV["IN"]}"
    exit 1
  end
  STDERR.puts out.join("\n").strip
  exit 0
'
