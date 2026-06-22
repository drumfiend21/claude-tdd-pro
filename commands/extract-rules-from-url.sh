#!/usr/bin/env bash
# commands/extract-rules-from-url.sh — ADR-0009 stage 1: segment a standards source into
# discrete candidate rules. Given a source document (local file or URL) and its shape, emit a
# JSON array of {rule_id, title, prose, source}. The downstream classifier (classify-rule.sh)
# and router (route-rule.sh) consume each segment.
#
# Shapes (per ADR-0009 — "per document shape"):
#   markdown-headings  (default) — each ATX heading (## / ###) starts a new rule; the prose is
#                                  the body until the next heading of the same-or-higher level.
#   numbered-list                — each top-level `N.` / `N)` item is a rule.
#
# CLI: --source <file|url> [--shape markdown-headings|numbered-list] [--source-id <id>] [--json]
# stderr: `extract source=<id> rules=<n> shape=<shape>`
# stdout (--json): the JSON array of segments.
# Exit: 0 ok | 2 usage | 3 source unreadable.

set -uo pipefail
SOURCE=""; SHAPE="markdown-headings"; SID=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --source)    SOURCE="${2-}"; shift 2 ;;
    --shape)     SHAPE="${2-}"; shift 2 ;;
    --source-id) SID="${2-}"; shift 2 ;;
    --json)      JSON=1; shift ;;
    -h|--help) echo "Usage: extract-rules-from-url.sh --source <file|url> [--shape markdown-headings|numbered-list] [--source-id <id>] [--json]" >&2; exit 0 ;;
    *) echo "extract-rules-from-url: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$SOURCE" ] && { echo "extract-rules-from-url: --source required" >&2; exit 2; }
[ -z "$SID" ] && SID="$(basename "$SOURCE" | sed 's/\.[^.]*$//')"

# Resolve the document text: local file, or fetch a URL (network-tolerant).
DOC="$(mktemp)"
case "$SOURCE" in
  http://*|https://*)
    if command -v curl >/dev/null 2>&1 && curl -fsSL --max-time 20 "$SOURCE" -o "$DOC" 2>/dev/null && [ -s "$DOC" ]; then :;
    else echo "extract-rules-from-url: source unreadable (offline/blocked): $SOURCE" >&2; rm -f "$DOC"; exit 3; fi ;;
  *)
    [ -f "$SOURCE" ] || { echo "extract-rules-from-url: not a file: $SOURCE" >&2; rm -f "$DOC"; exit 3; }
    cp "$SOURCE" "$DOC" ;;
esac

DOC="$DOC" SHAPE="$SHAPE" SID="$SID" JSON="$JSON" ruby -rjson -rdigest -e '
  Encoding.default_external = Encoding::UTF_8
  text = File.read(ENV["DOC"]) rescue ""
  shape = ENV["SHAPE"]; sid = ENV["SID"]
  segments = []

  def slug(s) = s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")[0, 60]

  if shape == "numbered-list"
    cur = nil
    text.each_line do |ln|
      if ln =~ /\A\s*(\d+)[.)]\s+(\S.*)/
        segments << cur if cur
        title = $2.strip
        cur = { title: title, body: +"" }
      elsif cur
        cur[:body] << ln
      end
    end
    segments << cur if cur
  else # markdown-headings
    cur = nil
    text.each_line do |ln|
      if ln =~ /\A(\#{1,6})\s+(\S.*)/   # ATX heading (escaped # so Ruby does not interpolate)
        level = $1.length
        next if level <= 1             # H1 = document title, not a rule
        segments << cur if cur
        cur = { title: $2.strip, body: +"" }
      elsif cur
        cur[:body] << ln
      end
    end
    segments << cur if cur
  end

  out = segments.each_with_index.map do |s, i|
    prose = s[:body].to_s.strip
    { "rule_id" => "#{sid}-#{format("%03d", i + 1)}-#{slug(s[:title])}",
      "title" => s[:title], "prose" => prose, "source" => sid,
      "content_hash" => "sha256:" + Digest::SHA256.hexdigest(s[:title] + "\n" + prose) }
  end.reject { |r| r["title"].to_s.empty? }

  STDERR.puts "extract source=#{sid} rules=#{out.size} shape=#{shape}"
  puts JSON.generate(out) if ENV["JSON"] == "1"
'
rc=$?
rm -f "$DOC"
exit $rc
