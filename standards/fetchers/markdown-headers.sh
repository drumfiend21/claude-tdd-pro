#!/usr/bin/env bash
# standards/fetchers/markdown-headers.sh — S-2 fetcher per §16:
# extracts content under a specific markdown heading, up to (but not
# including) the next sibling heading. Output to stderr.
#
# Usage:
#   markdown-headers.sh --in <md-file> --heading <heading-text>

set -uo pipefail

IN=""
HEADING=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --heading) HEADING="$2"; shift 2 ;;
    *) echo "markdown-headers: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$IN" ]] && { echo "markdown-headers: --in <file> required" >&2; exit 2; }
[[ -z "$HEADING" ]] && { echo "markdown-headers: --heading <text> required" >&2; exit 2; }
[[ ! -f "$IN" ]] && { echo "markdown-headers: file not found: $IN" >&2; exit 2; }

IN="$IN" HEADING="$HEADING" ruby -e '
  src = File.read(ENV["IN"])
  heading = ENV["HEADING"]
  lines = src.split("\n", -1)
  out = []
  in_section = false
  found = false
  current_level = nil
  lines.each do |line|
    if (m = line.match(/\A(#+)\s+(.+?)\s*\z/))
      level = m[1].length
      title = m[2]
      if title == heading
        in_section = true
        found = true
        current_level = level
        next
      end
      if in_section && level <= current_level
        in_section = false
      end
    end
    out << line if in_section
  end
  unless found
    STDERR.puts "markdown-headers: heading \"#{heading}\" not found in #{ENV["IN"]}"
    exit 1
  end
  STDERR.puts out.join("\n").strip
  exit 0
'
