#!/usr/bin/env bash
# standards/fetchers/rfc-style.sh — S-2 fetcher per §16:
# extracts a numbered section from an RFC-style text document
# (e.g. section "2.1" → content under "2.1." heading). Output to
# stderr.
#
# Usage:
#   rfc-style.sh --in <txt-file> --section <number>

set -uo pipefail

IN=""
SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    *) echo "rfc-style: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$IN" ]] && { echo "rfc-style: --in <file> required" >&2; exit 2; }
[[ -z "$SECTION" ]] && { echo "rfc-style: --section <num> required" >&2; exit 2; }
[[ ! -f "$IN" ]] && { echo "rfc-style: file not found: $IN" >&2; exit 2; }

SECTION="$SECTION" IN="$IN" ruby -e '
  section = ENV["SECTION"]
  text = File.read(ENV["IN"])
  lines = text.split("\n", -1)
  # Section heading shape: "<num>. <title>" or "<num>.<sub>. <title>".
  heading_re = /\A#{Regexp.escape(section)}\.\s/
  out = []
  in_section = false
  found = false
  lines.each do |line|
    if line =~ heading_re
      in_section = true
      found = true
      out << line
      next
    end
    if in_section
      # Stop at the next section heading at any level.
      if line =~ /\A\d+(\.\d+)*\.\s/ && !(line =~ /\A#{Regexp.escape(section)}\./)
        in_section = false
        break
      end
      out << line
    end
  end
  unless found
    STDERR.puts "rfc-style: section \"#{section}\" not found in #{ENV["IN"]}"
    exit 1
  end
  STDERR.puts out.join("\n").strip
  exit 0
'
