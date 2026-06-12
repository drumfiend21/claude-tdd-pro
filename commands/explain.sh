#!/usr/bin/env bash
# commands/explain.sh - S-35 plain-language explainer (v1.13 §27.15).
#
# Translates technical architecture terms and findings into plain BUSINESS
# language so a non-technical founder understands the options. A grounded
# glossary maps each term to {plain, why_it_matters, source_id}. Explains a
# single --term, or --annotate an S-34 options / S-33 requirements / S-26 review
# JSON (glossing every technical term it contains). cite-or-decline: a term not
# in the glossary is declined as unknown_term rather than invented.
#
# CLI:
#   --term <t>            explain one term; exit 0 known / 1 unknown
#   --annotate <json>     gloss every known term found in a JSON structure
#   --out <md>            annotation output (default standards/explanation.md)
#   --list-terms          print the glossary terms (JSON) to stdout; exit 0
#   --now <iso>           generated_at (default current UTC)
#   --dry-run             preview to stderr; write nothing (S2.14)
#
# stderr (term): term=<t> plain=<...> why=<...> source=<id> | unknown_term=<t>
# stderr (annotate): explanation=<path> annotated=<n> unknown=<n>
# Exit: 0 ok / 1 unknown term / 2 usage error.

set -uo pipefail

TERM=""; ANNOTATE=""; OUT=""; LIST=0; NOW=""; DRY_RUN=0; CLARIFY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --term)       TERM="${2-}";     shift 2 ;;
    --clarify)    CLARIFY="${2-}";  shift 2 ;;
    --annotate)   ANNOTATE="${2-}"; shift 2 ;;
    --out)        OUT="${2-}";      shift 2 ;;
    --list-terms) LIST=1;           shift ;;
    --now)        NOW="${2-}";      shift 2 ;;
    --dry-run)    DRY_RUN=1;        shift ;;
    -h|--help) echo "Usage: explain.sh --term <t> | --annotate <json> [--out <md>] | --list-terms [--dry-run]" >&2; exit 0 ;;
    *) echo "explain: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$OUT" ]; then OUT="standards/explanation.md"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

TERM="$TERM" CLARIFY="$CLARIFY" ANNOTATE="$ANNOTATE" OUT="$OUT" LIST="$LIST" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  term=ENV["TERM"]; annotate=ENV["ANNOTATE"]; out=ENV["OUT"]; list=ENV["LIST"]=="1"
  clarify=ENV["CLARIFY"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  # Grounded plain-language glossary (definitions are original plain-English;
  # source_id ties each to the authority that establishes the practice).
  G = {
    "least_privilege"        => ["give each part of the system only the access it truly needs", "if one part is breached, the damage cannot spread everywhere", "nist-800-53"],
    "encryption_at_rest"     => ["scramble stored data so it is unreadable if storage is stolen", "protects customer data and meets compliance obligations", "nist-800-53"],
    "encryption_in_transit"  => ["scramble data while it travels between systems", "stops anyone in the middle from reading sensitive information", "nist-800-53"],
    "access_control"         => ["decide who is allowed to do what in the system", "keeps the wrong people away from sensitive actions and data", "nist-800-53"],
    "audit_logging"          => ["keep a tamper-evident record of who did what and when", "required for compliance and essential for investigating incidents", "nist-800-53"],
    "boundary_protection"    => ["inspect and control traffic at the security perimeter", "required for government IL4/IL5 workloads and stops intrusions at the edge", "aws-dod-scca-prescriptive"],
    "multi_az"               => ["run copies in separate data centers in the same region", "one data-center outage will not take your service down", "aws-reliability-pillar"],
    "automated_failover"     => ["automatically switch to a healthy backup when the primary fails", "customers stay served without waiting for a human to react", "aws-reliability-pillar"],
    "multi_region"           => ["run the system in more than one geographic region", "survives even a whole-region outage for the highest resilience", "aws-reliability-pillar"],
    "health_check"           => ["continuously test whether each component is actually working", "lets the system route around broken parts before customers notice", "aws-reliability-pillar"],
    "backup"                 => ["keep recoverable copies of your data", "lets you restore after data loss or a bad change", "aws-rpo-rto-targets"],
    "synchronous_replication"=> ["write every change to two places at the same time", "you never lose recent data even if one copy fails", "aws-rpo-rto-targets"],
    "point_in_time_recovery" => ["rewind your data to any moment in the recent past", "recover cleanly from corruption or mistakes", "aws-rpo-rto-targets"],
    "autoscaling"            => ["add and remove capacity automatically as demand changes", "stays fast under load and you only pay for what you use", "aws-well-architected"],
    "caching"                => ["keep frequently used data close by for quick reuse", "faster responses for customers and lower cost", "aws-well-architected"],
    "rightsizing"            => ["match resource sizes to what the workload actually needs", "avoids overpaying for idle capacity", "finops-framework"],
    "managed_services"       => ["let the cloud provider run the undifferentiated heavy lifting", "your team spends time on product, not on plumbing", "finops-framework"],
    "monitoring"             => ["watch the systems health signals continuously", "you catch and fix problems before they reach customers", "google-sre-book"]
  }

  norm = lambda { |s| s.to_s.strip.downcase.gsub("-", "_") }

  # Keyword index (S-47): business-language phrases -> known technical concern,
  # so an unrecognised requirement can be clarified until it maps to a concern
  # S-33/S-34 can translate to architecture. Order = G order (first match wins).
  KW = {
    "encryption_at_rest"      => ["stolen", "at rest", "stored data", "encrypt the data", "data safe", "disk"],
    "encryption_in_transit"   => ["intercept", "in transit", "while it travels", "eavesdrop", "man in the middle"],
    "access_control"          => ["who can access", "permission", "roles", "authorize", "limit who"],
    "audit_logging"           => ["who did what", "audit", "record of actions", "trace actions", "compliance log"],
    "least_privilege"         => ["minimum access", "least privilege", "only the access"],
    "boundary_protection"     => ["perimeter", "il4", "il5", "boundary"],
    "multi_az"                => ["never go down", "stay up", "outage", "downtime", "always available", "data center fails"],
    "automated_failover"      => ["switch automatically", "failover", "take over automatically"],
    "multi_region"            => ["whole region", "geographic", "multiple regions", "region outage"],
    "health_check"            => ["detect broken", "is it working", "unhealthy"],
    "backup"                  => ["lose data", "restore", "recover data", "backup"],
    "synchronous_replication" => ["never lose recent", "zero data loss", "no data loss"],
    "point_in_time_recovery"  => ["rewind", "point in time", "undo corruption"],
    "autoscaling"             => ["traffic spike", "scale up", "handle load", "sudden growth", "get busy"],
    "caching"                 => ["faster", "speed up", "frequently used"],
    "rightsizing"             => ["overpay", "save money", "too expensive", "cheaper", "cut cost", "reduce cost"],
    "managed_services"        => ["managed", "provider runs", "less ops", "not maintain"],
    "monitoring"              => ["know when something breaks", "alert", "detect problems", "watch the system"]
  }
  resolve = lambda do |desc|
    d = desc.to_s.downcase
    G.keys.each { |concern| (KW[concern] || []).each { |kw| return concern if d.include?(kw) } }
    nil
  end
  prompt_for = lambda do |t|
    "I do not recognise \"#{t}\". In plain terms, what should it do for your users or business?"
  end

  if list
    STDOUT.puts JSON.pretty_generate(G.keys)
    STDERR.puts "terms=#{G.length}"
    exit 0
  end

  # S-47 clarification step: map a business description to a known concern.
  unless clarify.empty?
    t, _, desc = clarify.partition("=")
    concern = resolve.call(desc)
    if concern
      plain, why, src = G[concern]
      STDERR.puts "clarified=#{t.strip}"
      STDERR.puts "mapped_to=#{concern}"
      STDERR.puts "plain=#{plain}"
      STDERR.puts "source=#{src}"
      exit 0
    else
      STDERR.puts "unresolved=#{t.strip}"
      STDERR.puts "clarification_prompt=#{prompt_for.call(t.strip)}"
      exit 1
    end
  end

  unless term.empty?
    k = norm.call(term)
    if G.key?(k)
      plain, why, src = G[k]
      STDERR.puts "term=#{k}"
      STDERR.puts "plain=#{plain}"
      STDERR.puts "why=#{why}"
      STDERR.puts "source=#{src}"
      exit 0
    else
      # S-47: do not dead-end. Preserve the unknown_term signal AND ask the
      # founder to clarify (the agent loops with --clarify until it resolves).
      STDERR.puts "unknown_term=#{term}"
      STDERR.puts "clarification_needed=#{term}"
      STDERR.puts "clarification_prompt=#{prompt_for.call(term)}"
      exit 1
    end
  end

  unless annotate.empty?
    unless File.exist?(annotate)
      STDERR.puts "explain: file not found: #{annotate}"; exit 2
    end
    data = begin; JSON.parse(File.read(annotate)); rescue; nil; end
    if data.nil?
      STDERR.puts "explain: not valid json: #{annotate}"; exit 2
    end
    # Collect every string scalar in the structure.
    strings = []
    walk = lambda do |x|
      case x
      when Hash  then x.each_value { |v| walk.call(v) }
      when Array then x.each { |v| walk.call(v) }
      when String then strings << x
      end
    end
    walk.call(data)
    found = strings.map { |s| norm.call(s) }.uniq.select { |k| G.key?(k) }.sort
    unknown = strings.map { |s| norm.call(s) }.uniq.reject { |k| G.key?(k) }

    md = +"# Plain-Language Architecture Explanation - #{now}\n\n"
    md << "What the technical terms in your options mean, in business terms:\n\n"
    found.each do |k|
      plain, why, src = G[k]
      md << "- **#{k}**: #{plain} (why it matters: #{why}) [source: #{src}]\n"
    end
    md << "\n_No glossary terms recognised yet._\n" if found.empty?

    unless dry
      require "fileutils"
      d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
      File.write(out, md)
    end
    STDERR.puts "dry_run=true" if dry
    STDERR.puts "explanation=#{out}"
    STDERR.puts "annotated=#{found.length}"
    STDERR.puts "unknown=#{unknown.length}"
    exit 0
  end

  STDERR.puts "explain: provide --term, --annotate, or --list-terms"
  exit 2
'
exit $?
