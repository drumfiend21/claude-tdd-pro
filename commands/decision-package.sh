#!/usr/bin/env bash
# commands/decision-package.sh - S-50 closed-loop decision package (v1.15 M6,
# §27.22).
#
# Closes the vision->implementation loop. Bundles the chosen option (S-34) with
# its objective scores (S-46) and the toolchain (S-45) into one decided,
# enforceable package + a plain-language decision summary, and emits the
# next-step commands that feed S-28 (ADR), S-29 (build), and S-30 (enforce).
# Reports whether the loop is closed (choice is scored and has build
# requirements) or open (with the gap named).
#
# CLI:
#   --options <json>    S-34 architecture-options.json (required)
#   --scoring <json>    S-46 option-scoring.json (required)
#   --toolchain <json>  S-45 toolchain.json (optional)
#   --select <id>       chosen option (default: scoring recommended_option_id)
#   --out <json>        output (default standards/decision-package.json)
#   --now <iso> / --dry-run
#
# stderr: decision_package=<path> chosen=<id> loop_closed=<true|false>
#         total_score=<n> gaps=<csv>
# Exit: 0 success / 2 usage error.

set -uo pipefail

OPTS=""; SCORING=""; TOOLCHAIN=""; SELECT=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --options)   OPTS="${2-}";      shift 2 ;;
    --scoring)   SCORING="${2-}";   shift 2 ;;
    --toolchain) TOOLCHAIN="${2-}"; shift 2 ;;
    --select)    SELECT="${2-}";    shift 2 ;;
    --out)       OUT="${2-}";       shift 2 ;;
    --now)       NOW="${2-}";       shift 2 ;;
    --dry-run)   DRY_RUN=1;         shift ;;
    -h|--help) echo "Usage: decision-package.sh --options <json> --scoring <json> [--toolchain <json>] [--select <id>] [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "decision-package: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OPTS" ]; then echo "decision-package: --options <json> is required" >&2; exit 2; fi
if [ ! -f "$OPTS" ]; then echo "decision-package: options not found: $OPTS" >&2; exit 2; fi
if [ -z "$SCORING" ]; then echo "decision-package: --scoring <json> is required" >&2; exit 2; fi
if [ ! -f "$SCORING" ]; then echo "decision-package: scoring not found: $SCORING" >&2; exit 2; fi
if [ -z "$OUT" ]; then OUT="standards/decision-package.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

OPTS="$OPTS" SCORING="$SCORING" TOOLCHAIN="$TOOLCHAIN" SELECT="$SELECT" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  optf=ENV["OPTS"]; scof=ENV["SCORING"]; tcf=ENV["TOOLCHAIN"]; select=ENV["SELECT"]
  out=ENV["OUT"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  opts = JSON.parse(File.read(optf))
  scoring = JSON.parse(File.read(scof))
  options = opts["options"] || []
  scored  = scoring["scored_options"] || []

  chosen_id = select.empty? ? scoring["recommended_option_id"] : select
  chosen = options.find { |o| o["option_id"] == chosen_id }
  score  = scored.find { |s| s["option_id"] == chosen_id }

  if chosen.nil?
    STDERR.puts "decision-package: chosen option not found: #{chosen_id}"
    exit 2
  end

  build_requirements = chosen["build_requirements"] || []

  # Loop-closed check + gaps.
  gaps = []
  gaps << "not-scored" if score.nil?
  gaps << "no-build-requirements" if build_requirements.empty?
  loop_closed = gaps.empty?

  # Toolchain summary (category -> primary tool), if provided.
  toolchain_summary = []
  if !tcf.empty? && File.exist?(tcf)
    tc = JSON.parse(File.read(tcf)) rescue nil
    (tc && tc["recommendations"] || []).each do |r|
      toolchain_summary << {"category"=>r["category"], "primary_tool"=>r["tool"]}
    end
  end

  objective_scores = score ? score["scores"].merge({"total_score"=>score["total_score"]}) : {}
  iac = (toolchain_summary.find { |t| t["category"] == "iac" } || {})["primary_tool"] || "terraform"

  next_steps = {
    "adr_title"          => "Adopt #{chosen["summary"]}",
    "build_requirements" => build_requirements,
    "enforce_command"    => "cloud-conventions.sh --tool #{iac} --iac <generated-iac>"
  }

  package = {
    "schema_version"  => "1.0",
    "generated_at"    => now,
    "chosen_option"   => {"option_id"=>chosen["option_id"], "summary"=>chosen["summary"]},
    "objective_scores"=> objective_scores,
    "toolchain_summary"=> toolchain_summary,
    "next_steps"      => next_steps,
    "loop_closed"     => loop_closed,
    "gaps"            => gaps
  }

  # Plain-language decision summary (apostrophe-free for the embedded ruby).
  md = +"# Architecture Decision - #{now}\n\n"
  md << "Decision: adopt #{chosen["summary"]}.\n\n"
  if score
    s = score["scores"]
    md << "How it scores (0-1): cost-effective #{s["cost_effective"]}, performance #{s["performance_optimized"]}, customer #{s["customer_centric"]}, shareholder #{s["shareholder_centric"]} (overall #{score["total_score"]}).\n\n"
  end
  md << "Loop status: #{loop_closed ? "closed - ready to build and enforce" : "open - " + gaps.join(", ")}.\n\n"
  md << "Next steps:\n- Record the decision as an ADR titled \"#{next_steps["adr_title"]}\".\n- Build with: #{build_requirements.join(", ")}.\n- Enforce conventions before shipping.\n"
  unless toolchain_summary.empty?
    md << "\nToolchain: " + toolchain_summary.map { |t| "#{t["category"]}=#{t["primary_tool"]}" }.join(", ") + "\n"
  end

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(package) + "\n")
    File.write(File.join((d.empty? ? "." : d), "decision.md"), md)
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "decision_package=#{out}"
  STDERR.puts "chosen=#{chosen_id}"
  STDERR.puts "loop_closed=#{loop_closed}"
  STDERR.puts "total_score=#{score ? score["total_score"] : "none"}"
  STDERR.puts "gaps=#{gaps.join(",")}"
'
exit $?
