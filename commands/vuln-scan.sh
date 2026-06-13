#!/usr/bin/env bash
# commands/vuln-scan.sh - H-14 dependency vulnerability scan + remediation gate
# (v1.18 EO amendment §28.1; contract §2.30).
#
# Implements the EO "Promoting Advanced AI Innovation and Security" (2026-06-02)
# Sec. 2 AI-Cybersecurity-Clearinghouse find-AND-fix loop as a build gate. It reads
# a project's declared dependencies, matches them against an INJECTED (deterministic)
# advisory dataset, classifies each finding by severity, and gates:
#   critical/high -> block (exit 1)   medium/low -> warn (exit 0 + marker)
#   no finding    -> green no-op (exit 0)   no manifest -> skipped (exit 0)
# Every blocked finding NAMES its fixed_in remediation (the "and fix" half is
# mandatory, not advisory). The advisory dataset is injected here; a live feed is a
# production edge (per the §27.19 external-call-safety discipline).
#
# Plugin-wide (§28.10) AND cloud-architect (§28.11): manifest types span ordinary
# full-stack apps (package.json, requirements.txt, go.mod, Cargo.toml) AND cloud IaC
# supply chains (.terraform.lock.hcl provider pins).
#
# CLI:
#   --manifest <file>      dependency manifest (auto-detected by name/content)
#   --root <dir>           discover the first supported manifest under <dir>
#   --advisories <file>    injected advisory dataset (YAML or JSON). REQUIRED for a
#                          non-trivial scan; absent => no advisories => green.
#   --threshold <critical|high|medium|low>   block level (default high)
#   --emit <file>          write the findings as JSON (consumed by C-23 cvd-record)
#
# Advisory entry: { component, affected?, severity, fixed_in, advisory_id?, source? }
#   affected omitted => matches any version of that component.
#
# stderr: per-finding `vuln-scan component=<c> severity=<s> fixed_in=<v>`;
#         summary one of:
#           `vuln-scan no_dependencies=true status=skipped`
#           `vuln-scan status=green deps=<n> vulnerabilities=0`
#           `vuln-scan status=warn deps=<n> vulnerabilities=<n>`
#           `vuln-scan status=red critical=<n> high=<n>`
# Exit: 0 green/warn/skipped | 1 red (blocking vuln) | 2 usage error.

set -uo pipefail

MANIFEST=""; ROOT=""; ADVISORIES=""; THRESHOLD="high"; EMIT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)   MANIFEST="${2-}";   shift 2 ;;
    --root)       ROOT="${2-}";       shift 2 ;;
    --advisories) ADVISORIES="${2-}"; shift 2 ;;
    --threshold)  THRESHOLD="${2-}";  shift 2 ;;
    --emit)       EMIT="${2-}";       shift 2 ;;
    -h|--help)
      echo "Usage: vuln-scan.sh --manifest <file> | --root <dir> [--advisories <file>] [--threshold <level>] [--emit <file>]" >&2
      exit 0
      ;;
    *) echo "vuln-scan: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$THRESHOLD" in
  critical|high|medium|low) : ;;
  *) echo "vuln-scan: invalid --threshold: $THRESHOLD" >&2; exit 2 ;;
esac

MANIFEST="$MANIFEST" ROOT="$ROOT" ADVISORIES="$ADVISORIES" THRESHOLD="$THRESHOLD" EMIT="$EMIT" \
ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  manifest = ENV["MANIFEST"]; root = ENV["ROOT"]; adv_path = ENV["ADVISORIES"]
  threshold = ENV["THRESHOLD"]; emit = ENV["EMIT"]

  RANK = { "critical" => 4, "high" => 3, "medium" => 2, "low" => 1 }
  SUPPORTED = %w[package.json requirements.txt go.mod Cargo.toml .terraform.lock.hcl]

  # --- resolve the manifest file -------------------------------------------
  if manifest.empty? && !root.empty?
    SUPPORTED.each do |n|
      hit = Dir.glob(File.join(root, "**", n)).reject { |p| p =~ %r{/(node_modules|\.git|vendor)/} }.sort.first
      manifest = hit and break if hit
    end
    manifest = "" if manifest.nil?
  end

  def norm_ver(v); v.to_s.gsub(/^[\^~>=<\s vV]+/, "").strip; end

  # --- parse a manifest into [{name, version}] -----------------------------
  def parse(manifest)
    base = File.basename(manifest)
    text = File.exist?(manifest) ? File.read(manifest) : ""
    deps = []
    case base
    when "package.json"
      j = (JSON.parse(text) rescue {})
      %w[dependencies devDependencies].each do |k|
        (j[k] || {}).each { |n, v| deps << { "name" => n, "version" => norm_ver(v) } }
      end
    when "requirements.txt"
      text.each_line do |ln|
        ln = ln.sub(/#.*/, "").strip
        next if ln.empty?
        if ln =~ /^([A-Za-z0-9_.\-]+)\s*==\s*([^\s;]+)/
          deps << { "name" => $1, "version" => norm_ver($2) }
        end
      end
    when "go.mod"
      text.each_line do |ln|
        ln = ln.sub(%r{//.*}, "").strip
        next if ln.empty? || ln.start_with?("module ", "go ", "require (", "require(", ")", "require (")
        if ln =~ /^(?:require\s+)?(\S+)\s+v([0-9][^\s]*)/
          deps << { "name" => $1, "version" => norm_ver($2) }
        end
      end
    when "Cargo.toml"
      in_deps = false
      text.each_line do |ln|
        s = ln.strip
        if s =~ /^\[(.+)\]$/
          in_deps = ($1 =~ /dependencies/) ? true : false
          next
        end
        next unless in_deps
        if s =~ /^([A-Za-z0-9_\-]+)\s*=\s*"([^"]+)"/
          deps << { "name" => $1, "version" => norm_ver($2) }
        elsif s =~ /^([A-Za-z0-9_\-]+)\s*=\s*\{.*version\s*=\s*"([^"]+)"/
          deps << { "name" => $1, "version" => norm_ver($2) }
        end
      end
    when ".terraform.lock.hcl"
      cur = nil
      text.each_line do |ln|
        s = ln.strip
        if s =~ /^provider\s+"([^"]+)"/
          cur = $1.split("/").last           # e.g. registry.terraform.io/hashicorp/aws -> aws
        elsif cur && s =~ /^version\s*=\s*"([^"]+)"/
          deps << { "name" => cur, "version" => norm_ver($1) }
          cur = nil
        end
      end
    end
    deps
  end

  if manifest.empty? || !File.exist?(manifest) || !SUPPORTED.include?(File.basename(manifest))
    STDERR.puts "vuln-scan no_dependencies=true status=skipped"
    exit 0
  end

  deps = parse(manifest)
  if deps.empty?
    STDERR.puts "vuln-scan no_dependencies=true status=skipped"
    exit 0
  end

  # --- load advisories ------------------------------------------------------
  advisories = []
  unless adv_path.empty?
    raw = (YAML.safe_load(File.read(adv_path)) rescue nil)
    advisories = raw if raw.is_a?(Array)
  end

  # --- match ---------------------------------------------------------------
  findings = []
  deps.each do |d|
    advisories.each do |a|
      next unless a.is_a?(Hash)
      next unless a["component"].to_s == d["name"]
      aff = a["affected"]
      next unless aff.nil? || norm_ver(aff) == d["version"]
      findings << {
        "component"   => d["name"],
        "version"     => d["version"],
        "severity"    => a["severity"].to_s,
        "fixed_in"    => (a["fixed_in"].to_s.empty? ? "unavailable" : a["fixed_in"].to_s),
        "advisory_id" => a["advisory_id"].to_s,
        "source"      => a["source"].to_s,
      }
    end
  end

  tr = RANK[threshold] || 3
  blocking = findings.select { |f| (RANK[f["severity"]] || 0) >= tr }

  findings.each do |f|
    STDERR.puts "vuln-scan component=#{f["component"]} severity=#{f["severity"]} fixed_in=#{f["fixed_in"]}"
  end

  unless emit.empty?
    File.write(emit, JSON.pretty_generate(findings))
  end

  if blocking.any?
    nc = blocking.count { |f| f["severity"] == "critical" }
    nh = blocking.count { |f| f["severity"] == "high" }
    STDERR.puts "vuln-scan status=red critical=#{nc} high=#{nh}"
    exit 1
  elsif findings.any?
    STDERR.puts "vuln-scan status=warn deps=#{deps.size} vulnerabilities=#{findings.size}"
    exit 0
  else
    STDERR.puts "vuln-scan status=green deps=#{deps.size} vulnerabilities=0"
    exit 0
  end
'
