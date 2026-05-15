#!/usr/bin/env bash
# standards/fetchers/html-anchor.sh — S-2 fetcher per §16:
# extracts content under an HTML element with a given anchor id, up
# to (but not including) the next sibling heading. Output to stderr.
#
# Usage:
#   html-anchor.sh --in <html-file> --anchor <id>

set -uo pipefail

IN=""
ANCHOR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in) IN="$2"; shift 2 ;;
    --anchor) ANCHOR="$2"; shift 2 ;;
    *) echo "html-anchor: unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$IN" ]] && { echo "html-anchor: --in <file> required" >&2; exit 2; }
[[ -z "$ANCHOR" ]] && { echo "html-anchor: --anchor <id> required" >&2; exit 2; }
[[ ! -f "$IN" ]] && { echo "html-anchor: file not found: $IN" >&2; exit 2; }

IN="$IN" ANCHOR="$ANCHOR" ruby -e '
  src = File.read(ENV["IN"])
  anchor = ENV["ANCHOR"]
  # Locate <... id="<anchor>" ...>; capture content up to the next heading
  # tag (h1..h6) or end of document.
  m = src.match(/<(\w+)[^>]*id="#{Regexp.escape(anchor)}"[^>]*>(.*?)(?=<h[1-6]\b|<\/body>|\z)/m)
  if m
    STDERR.puts m[2].sub(/\A[^>]*>/, "").gsub(/<[^>]+>/, " ").strip
    exit 0
  else
    STDERR.puts "html-anchor: anchor id=\"#{anchor}\" not found in #{ENV["IN"]}"
    exit 1
  end
'
