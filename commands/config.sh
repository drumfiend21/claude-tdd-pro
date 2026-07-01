#!/usr/bin/env bash
# commands/config.sh — the single CTP rule-configuration surface (design: docs/design/
# v1.18-single-ctp-config-surface.md; §28.48). One discoverable, ESLint-like config file
# (ctp.config.yaml, a §2.5 profile) makes every scraped rule configurable in one place.
#
# Subcommands:
#   init  [--out <path>] [--force]      scaffold ctp.config.yaml: every active rule shown at its
#                                       default (commented), grouped by source namespace, annotated
#                                       with [src] + [enforced_by] + (default: <severity>). The active
#                                       config is `extends: [standard]` (defaults preserved); the user
#                                       uncomments a line to override (off | warn | error), ESLint-style.
#   print [--config <path>] [--for-file <f>]   the effective resolved config (delegates to the §2.5
#                                       resolver profiles/active.sh --emit-resolved).
#   resolve-path [--root <dir>]         emit the active config path per precedence:
#                                       <root>/ctp.config.yaml > userConfig.profile > profiles/standard.yaml.
#
# Exit: 0 ok | 2 usage.
set -uo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
GCQS="$PLUGIN_ROOT/generated-code-quality-standards"

SUB="${1-}"; shift || true
case "$SUB" in
  init|print|resolve-path) : ;;
  -h|--help|"") echo "Usage: config.sh (init|print|resolve-path) [opts]" >&2; exit 0 ;;
  *) echo "config: unknown subcommand: $SUB" >&2; exit 2 ;;
esac

# ---- shared: locate the active config per precedence -----------------------------------------
resolve_active_path() {
  local root="${1:-.}"
  if [ -f "$root/ctp.config.yaml" ]; then echo "$root/ctp.config.yaml"; return 0; fi
  if [ -f "ctp.config.yaml" ]; then echo "ctp.config.yaml"; return 0; fi
  # userConfig.profile (settings) -> profiles/<name>.yaml, else the shipped default
  local prof=""
  for sj in "$root/.claude-tdd-pro/settings.json" "$PLUGIN_ROOT/.claude-tdd-pro/settings.json"; do
    [ -f "$sj" ] || continue
    prof="$(SJ="$sj" node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.env.SJ,"utf8"));process.stdout.write(((j.userConfig||{}).profile)||"")}catch(e){}' 2>/dev/null)"
    [ -n "$prof" ] && break
  done
  if [ -n "$prof" ] && [ -f "$PLUGIN_ROOT/profiles/$prof.yaml" ]; then echo "$PLUGIN_ROOT/profiles/$prof.yaml"; return 0; fi
  echo "$PLUGIN_ROOT/profiles/standard.yaml"
}

if [ "$SUB" = "resolve-path" ]; then
  ROOT="."
  while [ $# -gt 0 ]; do case "$1" in --root) ROOT="${2-}"; shift 2 ;; *) shift ;; esac; done
  p="$(resolve_active_path "$ROOT")"
  echo "config resolve-path -> $p" >&2
  echo "$p"
  exit 0
fi

if [ "$SUB" = "print" ]; then
  CONFIG=""; FORFILE=""
  while [ $# -gt 0 ]; do case "$1" in
    --config) CONFIG="${2-}"; shift 2 ;; --for-file) FORFILE="${2-}"; shift 2 ;; *) shift ;;
  esac; done
  [ -z "$CONFIG" ] && CONFIG="$(resolve_active_path ".")"
  [ -f "$CONFIG" ] || { echo "config print: no config at $CONFIG" >&2; exit 2; }
  args=("$CONFIG" --tree "$GCQS" --emit-resolved)
  [ -n "$FORFILE" ] && args+=(--for-file "$FORFILE")
  bash "$PLUGIN_ROOT/profiles/active.sh" "${args[@]}" 2>&1 >/dev/null | tail -1
  echo "config print config=$CONFIG${FORFILE:+ for-file=$FORFILE}" >&2
  exit 0
fi

# ---- init: scaffold ctp.config.yaml ----------------------------------------------------------
OUT="ctp.config.yaml"; FORCE=0
while [ $# -gt 0 ]; do case "$1" in
  --out) OUT="${2-}"; shift 2 ;; --force) FORCE=1; shift ;; *) shift ;;
esac; done
[ -f "$OUT" ] && [ "$FORCE" -ne 1 ] && { echo "config init: $OUT exists (use --force to overwrite)" >&2; exit 2; }

GCQS="$GCQS" ruby -ryaml -e '
  gcqs = ENV["GCQS"]
  by_ns = {}
  Dir[File.join(gcqs, "*", "*.yaml")].sort.each do |f|
    d = (YAML.unsafe_load_file(f) rescue nil); next unless d.is_a?(Hash)
    ns = File.basename(File.dirname(f))
    src = (d["source"] || {})["id"].to_s
    (d["rules"] || []).each do |r|
      next unless r.is_a?(Hash) && r["id"]
      tools = (r["enforced_by"] || []).map { |b| b["tool"] || b["bundle"] }.compact.join(",")
      sev = r["severity"].to_s
      tok = %w[P0 P1].include?(sev) ? "error" : (sev == "P2" ? "warn" : "error")
      (by_ns[ns] ||= []) << [r["id"].to_s, src, tools, sev, tok]
    end
  end
  total = by_ns.values.map(&:size).sum
  puts "# ctp.config.yaml -- the single CTP rule-configuration surface (ESLint-style)."
  puts "# Edit to override any rule. The active config below is `extends: [standard]` so every rule"
  puts "# keeps its recommended default; UNCOMMENT a line and set off | warn | error to override."
  puts "# Tool-native checks are also configurable by namespaced id, e.g.  ruff/F401: off"
  puts "# Glob scoping goes under overrides:.  #{total} CTP rules across #{by_ns.size} source namespaces."
  puts "name: my-project"
  puts "extends:"
  puts "  - standard"
  puts ""
  puts "rules:"
  by_ns.keys.sort.each do |ns|
    puts "  # ----- #{ns} -----"
    by_ns[ns].sort_by { |x| x[0] }.each do |id, src, tools, sev, tok|
      puts "  # #{id}  [src: #{src}]  [enforced_by: #{tools}]  (default: #{sev})"
      puts "  # #{id}: #{tok}"
    end
  end
  puts ""
  puts "overrides: []"
' > "$OUT"

n="$(grep -cE '^  # g-|^  # [a-z]' "$OUT" 2>/dev/null || echo 0)"
echo "config init wrote=$OUT rules_listed=$(grep -cE '^  # [a-z0-9_-]+:' "$OUT") namespaces=$(grep -cE '^  # ----- ' "$OUT")" >&2
exit 0
