#!/usr/bin/env bash
# commands/business-translate.sh - S-33 business-to-technical translation
# (v1.13 §27.15).
#
# Maps a business-profile.json (from S-32) to pillar-keyed TECHNICAL concerns,
# each grounded in a catalog source. This is the bridge that turns a beginner's
# business answers ("mission-critical, can only be down minutes, regulated
# HIPAA data") into the technical requirements the S-26 review / S-29 build
# stages consume ("reliability: multi_az + automated_failover; security:
# encryption_at_rest + audit_logging"). The mapping is grounded in the AWS
# Well-Architected pillars (esp. the Reliability Pillar + RPO/RTO guidance) and
# NIST SP 800-53; cite-or-decline holds (an unbacked concern is needs_grounding).
#
# CLI:
#   --profile <json>      business-profile.json from S-32 (required)
#   --out <json>          technical-requirements.json
#                         (default standards/technical-requirements.json)
#   --catalog <path>      S-23 catalog (for grounding verification)
#   --eng-catalog <path>  S-30/S-31 catalog (for grounding verification)
#   --now <iso>           generated_at (default current UTC)
#   --dry-run             preview to stderr; write nothing (§2.14)
#
# stderr: technical_requirements=<path> concerns=<n> pillars=<csv>
#         reliability_concerns=<n> security_concerns=<n> needs_grounding=<n>
# Exit: 0 success / 2 usage error.

set -uo pipefail

PROFILE=""; OUT=""; CATALOG=""; ENG=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     PROFILE="${2-}"; shift 2 ;;
    --out)         OUT="${2-}";     shift 2 ;;
    --catalog)     CATALOG="${2-}"; shift 2 ;;
    --eng-catalog) ENG="${2-}";     shift 2 ;;
    --now)         NOW="${2-}";     shift 2 ;;
    --dry-run)     DRY_RUN=1;       shift ;;
    -h|--help) echo "Usage: business-translate.sh --profile <json> [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "business-translate: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$PROFILE" ]; then echo "business-translate: --profile <json> is required" >&2; exit 2; fi
if [ ! -f "$PROFILE" ]; then echo "business-translate: profile not found: $PROFILE" >&2; exit 2; fi
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
resolve() { if [ -f "$1" ]; then printf '%s' "$1"; elif [ -f "$PLUGIN_ROOT/$1" ]; then printf '%s' "$PLUGIN_ROOT/$1"; else printf '%s' "$1"; fi; }
if [ -z "$CATALOG" ]; then CATALOG="standards/cloud-architecture-sources.yaml"; fi
if [ -z "$ENG" ]; then ENG="standards/cloud-engineering-sources.yaml"; fi
CATALOG=$(resolve "$CATALOG"); ENG=$(resolve "$ENG")
if [ -z "$OUT" ]; then OUT="standards/technical-requirements.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

PROFILE="$PROFILE" OUT="$OUT" CATALOG="$CATALOG" ENG="$ENG" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -ryaml -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  profile=ENV["PROFILE"]; out=ENV["OUT"]; catalog=ENV["CATALOG"]; eng=ENV["ENG"]
  now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  prof = JSON.parse(File.read(profile))
  a = prof["answers"] || {}

  concerns = []  # {pillar, concern, driver, source_id}
  add = lambda { |pillar, concern, driver, src| concerns << {"pillar"=>pillar, "concern"=>concern, "driver"=>driver, "source_id"=>src} }

  # Reliability from criticality (AWS Reliability Pillar).
  if a["criticality"] == "mission-critical"
    add.call("reliability", "multi_az",           "criticality=mission-critical", "aws-reliability-pillar")
    add.call("reliability", "automated_failover", "criticality=mission-critical", "aws-reliability-pillar")
    add.call("reliability", "health_check",       "criticality=mission-critical", "aws-reliability-pillar")
  end
  # Reliability from availability tolerance / RTO (AWS RPO/RTO guidance).
  case a["availability_tolerance"]
  when "none", "minutes"
    add.call("reliability", "multi_az",           "availability_tolerance=#{a["availability_tolerance"]}", "aws-rpo-rto-targets")
    add.call("reliability", "automated_failover", "availability_tolerance=#{a["availability_tolerance"]}", "aws-rpo-rto-targets")
  when "hours"
    add.call("reliability", "health_check", "availability_tolerance=hours", "aws-rpo-rto-targets")
    add.call("reliability", "backup",       "availability_tolerance=hours", "aws-rpo-rto-targets")
  when "days"
    add.call("reliability", "backup", "availability_tolerance=days", "aws-rpo-rto-targets")
  end
  # Reliability from data-loss tolerance / RPO.
  case a["data_loss_tolerance"]
  when "none", "seconds"
    add.call("reliability", "synchronous_replication", "data_loss_tolerance=#{a["data_loss_tolerance"]}", "aws-rpo-rto-targets")
    add.call("reliability", "point_in_time_recovery",  "data_loss_tolerance=#{a["data_loss_tolerance"]}", "aws-rpo-rto-targets")
  when "minutes"
    add.call("reliability", "frequent_backup", "data_loss_tolerance=minutes", "aws-rpo-rto-targets")
  when "hours"
    add.call("reliability", "daily_backup", "data_loss_tolerance=hours", "aws-rpo-rto-targets")
  end
  # Security from data sensitivity (NIST 800-53).
  if %w[regulated confidential].include?(a["data_sensitivity"])
    add.call("security", "encryption_at_rest",    "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
    add.call("security", "encryption_in_transit", "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
    add.call("security", "access_control",        "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
  end
  # Security from compliance regime (NIST 800-53; DoD SCCA for IL/FedRAMP).
  cr = a["compliance_regime"].to_s
  if !cr.empty? && cr != "none"
    add.call("security", "audit_logging",     "compliance_regime=#{cr}", "nist-800-53")
    add.call("security", "encryption_at_rest","compliance_regime=#{cr}", "nist-800-53")
    if %w[il4 il5 fedramp].include?(cr)
      add.call("security", "boundary_protection", "compliance_regime=#{cr}", "aws-dod-scca-prescriptive")
    end
  end
  # Performance from scale (AWS Well-Architected).
  if %w[large hyperscale].include?(a["scale"])
    add.call("performance-efficiency", "autoscaling", "scale=#{a["scale"]}", "aws-well-architected")
    add.call("performance-efficiency", "caching",     "scale=#{a["scale"]}", "aws-well-architected")
  end
  # Cost from budget posture (FinOps).
  if a["budget_posture"] == "cost-first"
    add.call("cost-optimization", "rightsizing",      "budget_posture=cost-first", "finops-framework")
    add.call("cost-optimization", "managed_services", "budget_posture=cost-first", "finops-framework")
  end
  # Operational-excellence baseline (Google SRE).
  add.call("operational-excellence", "monitoring", "baseline", "google-sre-book")

  # S-51 observability + logging design: robust logging and analysis of deployed
  # services, tailored to what the user needs. Grounded in OpenTelemetry/SRE/NIST.
  add.call("operational-excellence", "centralized_logging", "baseline", "opentelemetry-docs")
  if a["criticality"] == "mission-critical" || a["communication_style"] == "event-driven"
    add.call("operational-excellence", "distributed_tracing", "criticality_or_event_driven", "opentelemetry-docs")
  end
  if a["criticality"] == "mission-critical"
    add.call("operational-excellence", "slo_alerting", "criticality=mission-critical", "google-sre-book")
  end
  cr_obs = a["compliance_regime"].to_s
  if !cr_obs.empty? && cr_obs != "none"
    add.call("operational-excellence", "audit_log_retention", "compliance_regime=#{cr_obs}", "nist-800-53")
  end
  if %w[regulated confidential].include?(a["data_sensitivity"])
    add.call("operational-excellence", "access_logging", "data_sensitivity=#{a["data_sensitivity"]}", "nist-800-53")
  end

  # S-52 software-engineering design surfaces (grounded; tailored to the profile).
  # New pillar keys keep the five Well-Architected pillars (S-34/S-29) untouched.
  ds = a["data_sensitivity"].to_s
  cr2 = a["compliance_regime"].to_s
  scope = a["integration_scope"].to_s
  comm = a["communication_style"].to_s
  exposed = %w[external-partner public].include?(scope)
  sensitive = %w[regulated confidential].include?(ds)
  # Testing (always) + contract testing when services integrate.
  add.call("testing", "unit_testing",        "baseline", "fowler-test-pyramid")
  add.call("testing", "integration_testing", "baseline", "fowler-test-pyramid")
  if comm == "event-driven" || exposed
    add.call("testing", "contract_testing", "services_integrate", "enterprise-integration-patterns")
  end
  # Dependency versioning + compatibility (futureproofing) - always.
  add.call("dependencies", "dependency_pinning",          "baseline", "semver")
  add.call("dependencies", "automated_dependency_updates", "baseline", "google-eng-practices")
  add.call("dependencies", "compatibility_testing",        "baseline", "semver")
  # Identity: authentication / authorization / MFA.
  if sensitive || exposed
    add.call("identity", "authentication", "sensitive_or_exposed", "oauth2-oidc")
  end
  if ds != "public"
    add.call("identity", "authorization_rbac", "data_sensitivity=#{ds}", "owasp-asvs")
  end
  if ds == "regulated" || (!cr2.empty? && cr2 != "none")
    add.call("identity", "mfa", "regulated_or_compliance", "nist-800-53")
  end
  if scope == "public"
    add.call("identity", "token_validation", "integration_scope=public", "owasp-asvs")
  end
  # Object storage (data buckets).
  if ds != "public" || !a["data_volume"].to_s.empty?
    add.call("storage", "object_storage_encryption", "data_at_rest", "nist-800-53")
    add.call("storage", "public_access_block",       "data_at_rest", "nist-800-53")
  end
  if %w[large very-large].include?(a["data_volume"])
    add.call("storage", "bucket_versioning", "data_volume=#{a["data_volume"]}", "aws-well-architected")
    add.call("storage", "lifecycle_policy",  "data_volume=#{a["data_volume"]}", "aws-well-architected")
  end
  # REST APIs.
  if %w[synchronous mixed].include?(comm) || scope == "public"
    add.call("api", "rest_api_gateway", "request_response_or_public", "microsoft-rest-api-guidelines")
  end
  if scope == "public"
    add.call("api", "rate_limiting",     "integration_scope=public", "microsoft-rest-api-guidelines")
    add.call("api", "request_validation","integration_scope=public", "microsoft-rest-api-guidelines")
  end
  if exposed
    add.call("api", "api_versioning", "integration_scope=#{scope}", "microsoft-rest-api-guidelines")
  end
  # Real-time sockets.
  if a["data_cadence"] == "real-time"
    add.call("realtime", "websocket_gateway", "data_cadence=real-time", "enterprise-integration-patterns")
    add.call("realtime", "connection_auth",   "data_cadence=real-time", "oauth2-oidc")
  end
  # Edge: HTTP security headers + CORS (public surface).
  if scope == "public"
    add.call("edge", "security_headers", "integration_scope=public", "owasp-secure-headers")
    add.call("edge", "cors_policy",      "integration_scope=public", "owasp-secure-headers")
  end

  # S-53 global delivery + frontend performance (full-stack, international,
  # UI-responsive). Fire for public-facing apps; global concerns add at scale.
  if scope == "public"
    add.call("performance-efficiency", "cdn",          "public_facing_fast_requests", "aws-well-architected")
    add.call("performance-efficiency", "edge_caching", "public_facing_fast_requests", "aws-well-architected")
    add.call("frontend", "spa_hosting",      "public_facing_ui", "aws-well-architected")
    add.call("frontend", "http_compression", "ui_responsiveness", "aws-well-architected")
    if %w[large hyperscale].include?(a["scale"])
      add.call("reliability", "multi_region",          "international_users_at_scale", "aws-reliability-pillar")
      add.call("reliability", "latency_based_routing", "international_low_latency",    "aws-reliability-pillar")
    end
  end

  # S-39 data + distributed concerns (grounded in the S-37 catalogs); fire only
  # when the --with-data intake answers are present.
  case a["consistency_need"]
  when "strong"
    add.call("data", "strong_consistency",      "consistency_need=strong",   "patterns-of-distributed-systems")
    add.call("data", "synchronous_replication", "consistency_need=strong",   "patterns-of-distributed-systems")
  when "eventual"
    add.call("data", "eventual_consistency",    "consistency_need=eventual", "patterns-of-distributed-systems")
  end
  if %w[large very-large].include?(a["data_volume"])
    add.call("data", "partitioning", "data_volume=#{a["data_volume"]}", "azure-data-store-models")
    add.call("data", "sharding",     "data_volume=#{a["data_volume"]}", "azure-data-store-models")
  end
  if a["read_write_pattern"] == "analytics"
    add.call("data", "data_warehouse", "read_write_pattern=analytics", "aws-data-analytics-lens")
  end
  case a["communication_style"]
  when "event-driven"
    add.call("integration", "message_queue",     "communication_style=event-driven", "enterprise-integration-patterns")
    add.call("integration", "dead_letter_queue", "communication_style=event-driven", "enterprise-integration-patterns")
    add.call("integration", "outbox_pattern",    "communication_style=event-driven", "enterprise-integration-patterns")
  when "synchronous"
    add.call("integration", "api_gateway", "communication_style=synchronous", "enterprise-integration-patterns")
  end
  if %w[external-partner public].include?(a["integration_scope"])
    add.call("integration", "anti_corruption_layer", "integration_scope=#{a["integration_scope"]}", "enterprise-integration-patterns")
    add.call("integration", "contract_test",         "integration_scope=#{a["integration_scope"]}", "enterprise-integration-patterns")
  end
  if a["read_write_pattern"] == "analytics" && a["consistency_need"] == "mixed"
    add.call("distributed", "cqrs", "analytics+mixed-consistency", "fowler-cqrs")
  end
  if a["communication_style"] == "event-driven" && a["criticality"] == "mission-critical"
    add.call("distributed", "saga",           "event-driven+mission-critical", "fowler-event-sourcing")
    add.call("distributed", "event_sourcing", "event-driven+mission-critical", "fowler-event-sourcing")
  end

  # §30.1 — CONSUME the S-57 per-namespace probe COMMITMENTS (v1.1 profile). Each committed posture adds a
  # GROUNDED concern (cited by the probe source_id, already grounded) so the stated founder commitments
  # steer the produced options — closing the input->design half of the full-surface loop. Fires only when a
  # v1.1 profile carries `probes` (v1.0 profiles have none -> behavior unchanged, back-compat by construction).
  probes = prof["probes"] || {}
  pget = lambda { |ns, key| (probes[ns] || {})[key] }
  probe_driven = 0
  padd = lambda { |pillar, concern, driver, src| add.call(pillar, concern, driver, src); probe_driven += 1 }
  case pget.call("owasp", "owasp_threat_posture")
  when "hardened", "adversarial"
    padd.call("security", "threat_modeling",     "owasp_threat_posture=#{pget.call("owasp","owasp_threat_posture")}", "owasp-asvs")
    padd.call("security", "penetration_testing", "owasp_threat_posture=#{pget.call("owasp","owasp_threat_posture")}", "owasp-asvs")
  end
  case pget.call("slsa", "slsa_build_level")
  when "l2", "l3"
    padd.call("security", "provenance_attestation", "slsa_build_level=#{pget.call("slsa","slsa_build_level")}", "slsa-framework")
  end
  case pget.call("sbom", "sbom_generation")
  when "on-release", "every-build"
    padd.call("security", "sbom_generation", "sbom_generation=#{pget.call("sbom","sbom_generation")}", "slsa-framework")
  end
  case pget.call("react", "react_accessibility_target")
  when "wcag-aa", "wcag-aaa"
    padd.call("frontend", "accessibility_conformance", "react_accessibility_target=#{pget.call("react","react_accessibility_target")}", "wcag-2-2")
  end
  if pget.call("aws", "aws_region_strategy") == "multi-region"
    padd.call("reliability", "multi_region", "aws_region_strategy=multi-region", "aws-well-architected")
  end
  if pget.call("azure", "azure_region_strategy") == "multi-region"
    padd.call("reliability", "multi_region", "azure_region_strategy=multi-region", "azure-well-architected")
  end
  if pget.call("gcp", "gcp_region_strategy") == "multi-region"
    padd.call("reliability", "multi_region", "gcp_region_strategy=multi-region", "gcp-architecture-framework")
  end
  if pget.call("cfn", "cfn_stack_policy") == "protected"
    padd.call("operational-excellence", "stack_protection", "cfn_stack_policy=protected", "aws-cloudformation-best-practices")
  end
  case pget.call("aws", "aws_cost_guardrails")
  when "budgets", "hard-caps"
    padd.call("cost-optimization", "cost_guardrails", "aws_cost_guardrails=#{pget.call("aws","aws_cost_guardrails")}", "finops-framework")
  end
  if pget.call("k8s", "k8s_multitenancy") == "multi-tenant"
    padd.call("security", "namespace_isolation", "k8s_multitenancy=multi-tenant", "cncf-cloud-native")
  end
  case pget.call("hashicorp", "hashicorp_state_backend")
  when "remote", "remote-locked"
    padd.call("operational-excellence", "remote_state_locking", "hashicorp_state_backend=#{pget.call("hashicorp","hashicorp_state_backend")}", "hashicorp-terraform-style-guide")
  end
  if pget.call("jwt", "jwt_token_lifetime") == "short" || pget.call("jwt", "jwt_refresh_strategy") == "rotating"
    padd.call("identity", "short_lived_tokens", "jwt_commitment", "oauth2-oidc")
  end
  if pget.call("observability", "observability_signal_depth") == "full-tracing"
    padd.call("operational-excellence", "distributed_tracing", "observability_signal_depth=full-tracing", "opentelemetry-docs")
  end

  # Dedupe by (pillar, concern); first driver/source wins.
  seen = {}; deduped = []
  concerns.each do |c|
    k = "#{c["pillar"]}:#{c["concern"]}"
    next if seen[k]
    seen[k] = true; deduped << c
  end

  # Grounding verification (cite-or-decline): a concern whose source is in no
  # catalog is marked needs_grounding. §30.1: also load the EO-security + universal
  # source catalogs so probe commitments citing e.g. slsa-framework / wcag-2-2 are
  # recognized as grounded (additive — can only reduce needs_grounding, never raise it).
  grounded = {}
  sdir = File.dirname(catalog)
  [catalog, eng,
   File.join(sdir, "data-architecture-sources.yaml"), File.join(sdir, "distributed-systems-sources.yaml"),
   File.join(sdir, "eo-security-sources.yaml"), File.join(sdir, "sources.yaml")].each do |cf|
    next unless File.exist?(cf)
    d = begin; YAML.unsafe_load_file(cf); rescue; nil; end
    next unless d.is_a?(Array)
    d.each { |e| grounded[e["id"]] = true if e.is_a?(Hash) && e["id"] }
  end
  needs = []
  deduped.each do |c|
    unless grounded[c["source_id"]]
      c["grounding"] = "needs_grounding"; needs << c["concern"]
    else
      c["grounding"] = "grounded"
    end
  end

  by_pillar = {}
  deduped.each { |c| (by_pillar[c["pillar"]] ||= []) << {"concern"=>c["concern"], "driver"=>c["driver"], "source_id"=>c["source_id"], "grounding"=>c["grounding"]} }

  doc = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "concerns_total" => deduped.length,
    "needs_grounding"=> needs.uniq,
    "probes_consumed"=> probe_driven,
    "pillars"        => by_pillar
  }

  unless dry
    require "fileutils"
    dd = File.dirname(out); FileUtils.mkdir_p(dd) unless dd.empty? || dd == "."
    File.write(out, JSON.pretty_generate(doc) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "technical_requirements=#{out}"
  STDERR.puts "concerns=#{deduped.length}"
  STDERR.puts "pillars=#{by_pillar.keys.sort.join(",")}"
  STDERR.puts "reliability_concerns=#{(by_pillar["reliability"]||[]).length}"
  STDERR.puts "security_concerns=#{(by_pillar["security"]||[]).length}"
  STDERR.puts "needs_grounding=#{needs.uniq.length}"
  STDERR.puts "probes_consumed=#{probe_driven}"
'
exit $?
