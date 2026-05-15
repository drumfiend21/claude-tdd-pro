set -uo pipefail
LIST=""
while [[ $# -gt 0 ]]; do
  case "$1" in --list) LIST="$2"; shift 2 ;; *) shift ;; esac
done
[[ -z "$LIST" || ! -f "$LIST" ]] && { echo "validate-source-list: --list required" >&2; exit 2; }
LIST="$LIST" ruby -ryaml -e '
d = YAML.load_file(ENV["LIST"]) rescue {}
sources = d["sources"] || []
seen = {}
dupes = []
sources.each do |s|
  if seen[s["id"]]
    dupes << s["id"]
  else
    seen[s["id"]] = true
  end
end
if dupes.any?
  STDERR.puts "validate-source-list: duplicate id(s): #{dupes.uniq.join(", ")}"
  exit 2
end
STDERR.puts "validate-source-list: ok"
'
