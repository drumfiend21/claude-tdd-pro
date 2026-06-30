#!/usr/bin/env bash
# rubric/runners/emit-tool-config.sh — Layer-2 native-config EMITTER (§28.51). Renders the
# tool-NATIVE options from the single config layer (enforced_by[].options / ctp.config.yaml) into
# the tool's own on-disk config file, so options written once in CTP take effect in the real tool.
# NO TRANSFORMER: the options ARE the tool's keys; this just serializes them to the tool's format.
#
# The output format + filename + config flag come from standards/tool-option-surfaces.yaml
# (`render: { fmt, file, flag }`). Supported fmt: json | yaml | toml | ini.
#
# §28.58 universal config object — second render METHOD: a tool configured by CLI FLAGS (not a config
# file) declares `render: { method: cli, map: { <option-key>: <flag> } }`. Options then project to a
# CLI flag string (boolean true -> bare flag; scalar -> `flag value`; array -> flag repeated; an
# unmapped key -> generic `--<key> <value>`), emitted to `<tool>.flags` AND printed to stdout so the
# runner can splice it. This makes the gap tools (checkov via file, semgrep/trivy via cli) and any
# future tool projectable from the single config — no tool-specific option is unprovidable.
#
# CLI: --tool <name> --options <json> --out <dir>
# stdout: the emitted config file path, OR (cli method) the rendered flag string
# stderr: `emit-tool-config tool=<t> fmt=<f> file=<path>` | `... method=cli flags=<n>`
# Exit: 0 ok (incl. no-op) | 2 usage.
set -uo pipefail
TOOL=""; OPTS=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2-}"; shift 2 ;;
    --options) OPTS="${2-}"; shift 2 ;;
    --out) OUT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: emit-tool-config.sh --tool <name> --options <json> --out <dir>" >&2; exit 0 ;;
    *) echo "emit-tool-config: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$TOOL" ] && { echo "emit-tool-config: --tool required" >&2; exit 2; }
[ -z "$OUT" ] && { echo "emit-tool-config: --out required" >&2; exit 2; }
[ -z "$OPTS" ] && OPTS="{}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
CAT="$PLUGIN_ROOT/standards/tool-option-surfaces.yaml"
mkdir -p "$OUT" 2>/dev/null || true

CATALOG="$CAT" TOOL="$TOOL" OPTS="$OPTS" OUT="$OUT" ruby -ryaml -rjson -e '
  cat = YAML.unsafe_load_file(ENV["CATALOG"]) rescue {}
  tdef = ((cat["tools"]||{})[ENV["TOOL"]]) || {}
  render = tdef["render"]
  # no render mapping (optionless tool, or not yet wired) -> no-op (empty stdout)
  if !render.is_a?(Hash) then STDERR.puts("emit-tool-config tool=#{ENV["TOOL"]} fmt=- reason=no-render-mapping"); exit 0 end
  opts = JSON.parse(ENV["OPTS"]) rescue {}
  if !opts.is_a?(Hash) || opts.empty? then STDERR.puts("emit-tool-config tool=#{ENV["TOOL"]} fmt=#{render["fmt"]} reason=no-options"); exit 0 end

  # §28.58 second render method: CLI-FLAG tools (semgrep, trivy, ...) project options to a flag string.
  if render["method"].to_s == "cli"
    map = render["map"].is_a?(Hash) ? render["map"] : {}
    toks = []
    opts.each do |k, v|
      flag = map[k] ? map[k].to_s : "--#{k}"        # mapped flag, else generic --<key>
      case v
      when true        then toks << flag
      when false, nil  then next                    # disabled option -> omit
      when Array       then v.each { |x| toks << flag << x.to_s }
      else                  toks << flag << v.to_s
      end
    end
    flags = toks.join(" ")
    ffile = File.join(ENV["OUT"], "#{ENV["TOOL"]}.flags")
    File.write(ffile, flags + "\n")
    STDERR.puts("emit-tool-config tool=#{ENV["TOOL"]} method=cli flags=#{opts.size} file=#{ffile}")
    print flags
    exit 0
  end

  fmt = render["fmt"].to_s; file = render["file"].to_s
  path = File.join(ENV["OUT"], file)

  def toml_val(v)
    case v
    when Array then "[" + v.map{|x| toml_val(x)}.join(", ") + "]"
    when String then v.inspect
    when true, false then v.to_s
    when Numeric then v.to_s
    when Hash then "{ " + v.map{|k,x| "#{k} = #{toml_val(x)}"}.join(", ") + " }"
    else v.inspect
    end
  end

  body =
    case fmt
    when "json" then JSON.pretty_generate(opts) + "\n"
    when "yaml" then YAML.dump(opts)
    when "toml" then opts.map{|k,v| "#{k} = #{toml_val(v)}"}.join("\n") + "\n"
    when "ini"  then "[#{ENV["TOOL"]}]\n" + opts.map{|k,v| "#{k} = #{v.is_a?(Array) ? v.join(",") : v}"}.join("\n") + "\n"
    else nil
    end
  if body.nil? then STDERR.puts("emit-tool-config tool=#{ENV["TOOL"]} fmt=#{fmt} reason=unsupported-fmt"); exit 0 end
  File.write(path, body)
  STDERR.puts("emit-tool-config tool=#{ENV["TOOL"]} fmt=#{fmt} file=#{path}")
  print path
'
