#!/usr/bin/env bash
# commands/promote-cloud-rules.sh - promote cloud/EO guidance corpora into first-class,
# grounded, ESLint-style detector rules (S-7 promotion; v1.18 §28.15 Layer-A activation).
#
# The cloud/governance namespaces (aws, azure, gcp, hashicorp, linux-foundation,
# security-governance, us-government) ship reading-source GUIDANCE (rules: []) that
# grounds the /architect engine. This command ACTIVATES that guidance into enforced
# write-time detector rules: for each namespace it generates a §2.1 rule file
# (generated-code-quality-standards/<ns>/<ns>-iac-enforcement.yaml) whose rules each
# cite an authoritative source (provenance) and run via the shared §2.2 detector
# rubric/detectors/cloud-guidance-rule.sh. It also emits the detector's check manifest
# rubric/detectors/cloud-guidance-rules.json from the SAME source-of-truth, so rules
# and detector never drift. Deterministic + idempotent: re-running yields identical
# files. The guidance reading-sources are left untouched (guidance + enforcement coexist).
#
# CLI: [--root <dir>] (default plugin root)   exit 0 ok / 2 usage.

set -uo pipefail
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: promote-cloud-rules.sh [--root <dir>]" >&2; exit 0 ;;
    *) echo "promote-cloud-rules: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

ROOT="$ROOT" ruby -ryaml -rjson -rdigest -rfileutils -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]

  # --- single source of truth: per-namespace authority + grounded detector rules ----
  # rule = [id, name, description, token, mode, applies, source_id, severity, type]
  NS = [
    { ns: "aws", sid: "aws-well-architected", pub: "Amazon Web Services",
      url: "https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html",
      lic: "Reference/educational use - (c) Amazon Web Services",
      rules: [
        ["g-aws-no-unrestricted-ingress","no-unrestricted-ingress","Security groups and firewall rules must not allow unrestricted 0.0.0.0/0 ingress; expose only the ports and CIDRs a workload requires.","0.0.0.0/0","forbid","*.tf","aws-prescriptive-security","P0","problem"],
        ["g-aws-tag-resources","tag-resources","Cloud resources must carry tags so ownership, cost allocation, and governance are traceable.","tags","require","*.tf","aws-well-architected","P2","suggestion"],
      ] },
    { ns: "azure", sid: "azure-well-architected", pub: "Microsoft",
      url: "https://learn.microsoft.com/azure/well-architected/",
      lic: "Reference/educational use - (c) Microsoft",
      rules: [
        ["g-azure-no-unrestricted-ingress","no-unrestricted-ingress","Network security groups must not permit unrestricted 0.0.0.0/0 inbound access.","0.0.0.0/0","forbid","*.bicep,*.tf","azure-well-architected","P0","problem"],
        ["g-azure-encrypt-at-rest","encrypt-at-rest","Data stores must declare encryption at rest.","encryption","require","*.bicep,*.tf","azure-well-architected","P1","problem"],
      ] },
    { ns: "gcp", sid: "gcp-architecture-framework", pub: "Google Cloud",
      url: "https://cloud.google.com/architecture/framework",
      lic: "Reference/educational use - (c) Google Cloud",
      rules: [
        ["g-gcp-no-unrestricted-ingress","no-unrestricted-ingress","Firewall rules must not allow unrestricted 0.0.0.0/0 ingress.","0.0.0.0/0","forbid","*.tf","gcp-architecture-framework","P0","problem"],
        ["g-gcp-enable-audit-logs","enable-audit-logs","Projects and services must enable audit logging for accountability.","audit","require","*.tf","gcp-architecture-framework","P1","problem"],
      ] },
    { ns: "hashicorp", sid: "terraform-docs", pub: "HashiCorp",
      url: "https://developer.hashicorp.com/terraform/docs",
      lic: "Reference/educational use - (c) HashiCorp",
      rules: [
        ["g-hashicorp-pin-required-version","pin-required-version","Terraform configurations must pin a required_version to keep builds reproducible.","required_version","require","*.tf","terraform-docs","P1","problem"],
        ["g-hashicorp-declare-required-providers","declare-required-providers","Terraform configurations must declare required_providers with version constraints.","required_providers","require","*.tf","terraform-docs","P1","problem"],
      ] },
    { ns: "linux-foundation", sid: "cncf-cloud-native", pub: "Cloud Native Computing Foundation",
      url: "https://www.cncf.io/",
      lic: "Reference/educational use - (c) CNCF",
      rules: [
        ["g-linux-foundation-set-resource-limits","set-resource-limits","Kubernetes workloads must declare resource requests and limits to protect cluster stability.","resources","require","*.yaml,*.yml","cncf-cloud-native","P1","problem"],
        ["g-linux-foundation-liveness-probe","liveness-probe","Kubernetes workloads should declare a livenessProbe so the platform can self-heal.","livenessProbe","require","*.yaml,*.yml","cncf-cloud-native","P2","suggestion"],
      ] },
    { ns: "security-governance", sid: "cisa-ssdf", pub: "U.S. NIST",
      url: "https://csrc.nist.gov/projects/ssdf",
      lic: "Reference/educational use - (c) U.S. NIST",
      rules: [
        ["g-security-governance-require-provenance","require-provenance","Build/deploy units must emit supply-chain provenance/attestation (SLSA).","provenance","require","*.tf,*.bicep","slsa-framework","P1","problem"],
        ["g-security-governance-no-known-exploited-ingress","no-known-exploited-ingress","Forbid unrestricted 0.0.0.0/0 ingress - a routinely known-exploited misconfiguration (CISA KEV).","0.0.0.0/0","forbid","*.tf,*.bicep","cisa-kev","P0","problem"],
      ] },
    { ns: "us-government", sid: "nist-zero-trust", pub: "U.S. NIST",
      url: "https://csrc.nist.gov/pubs/sp/800/207/final",
      lic: "Reference/educational use - (c) U.S. NIST",
      rules: [
        ["g-us-government-encrypt-at-rest","encrypt-at-rest","Federal-system data must be encrypted at rest (NIST/Zero Trust).","encrypt","require","*.tf,*.bicep","nist-zero-trust","P1","problem"],
        ["g-us-government-audit-logging","audit-logging","Federal systems must enable audit logging at the boundary (DoD SCCA).","logging","require","*.tf,*.bicep","dod-scca","P1","problem"],
      ] },
  ]

  manifest = { "generated_by" => "promote-cloud-rules.sh", "rules" => {} }

  NS.each do |n|
    ids = n[:rules].map { |r| r[0] }
    digest = Digest::SHA256.hexdigest("#{n[:ns]}|#{n[:sid]}|#{ids.join(",")}")
    doc = {}
    doc["source"] = {
      "id" => n[:sid],
      "authoritative_publisher" => n[:pub],
      "authoritative_url" => n[:url],
      "registry_link" => "STANDARDS-URLS.yaml",
      "fetched_at" => "2026-06-15T00:00:00Z",
      "content_hash" => "sha256:#{n[:ns]}-iac-enforcement-placeholder-content-hash-for-bootstrap",
      "fetch_frequency" => "daily",
      "fragility_tier" => "medium",
      "license_note" => n[:lic],
    }
    # §28.24 Wave-3 prose-as-code: the unrestricted-ingress rules carry a literal
    # 0.0.0.0/0 token that appears verbatim in architecture prose, so an ADR proposing
    # it red-flags via the prose-judge keyword tier before any Terraform is written.
    prose_ids = %w[g-aws-no-unrestricted-ingress g-gcp-no-unrestricted-ingress g-azure-no-unrestricted-ingress]
    doc["rules"] = n[:rules].map do |id, name, desc, token, mode, applies, source, sev, type|
      manifest["rules"][id] = { "token" => token, "mode" => mode, "applies" => applies,
                                "source" => source, "namespace" => n[:ns], "severity" => sev }
      rule = {
        "id" => id, "name" => name, "description" => desc,
        "detector" => "cloud-guidance-rule.sh",
        "type" => type, "fixable" => nil, "has_suggestions" => false,
        "deprecated" => false, "replaced_by" => [], "docs_url" => n[:url],
        "requires_type_checking" => false, "recommended" => true,
        "severity" => sev, "version" => "1.0.0", "semver" => "1.0.0",
        "rule_state" => "stable",
        "provenance" => [ { "source" => source, "section" => "convention" } ],
      }
      if prose_ids.include?(id)
        rule["applies_to_prose"] = true
        rule["applies_to_prose_kinds"] = ["architecture", "adr"]
      end
      rule
    end
    doc["recommended_set"] = ids
    doc["all_set"] = ids.dup

    dir = File.join(root, "generated-code-quality-standards", n[:ns])
    FileUtils.mkdir_p(dir) rescue Dir.mkdir(dir) unless Dir.exist?(dir)
    path = File.join(dir, "#{n[:ns]}-iac-enforcement.yaml")
    File.write(path, doc.to_yaml)
    STDERR.puts "promoted #{n[:ns]}: #{ids.size} rules -> #{path}"
  end

  File.write(File.join(root, "rubric", "detectors", "cloud-guidance-rules.json"),
             JSON.pretty_generate(manifest) + "\n")
  total = manifest["rules"].size
  STDERR.puts "promote-cloud-rules: #{NS.size} namespaces activated, #{total} detector rules"
'
# Re-apply the ADR-0008 Wave 2 4-axis migration so re-generation never drops applies_to/enforced_by.
[ -x "$(dirname "$0")/migrate-rules-to-applies-to.sh" ] && \
  bash "$(dirname "$0")/migrate-rules-to-applies-to.sh" --root "$ROOT" >/dev/null 2>&1 || true
exit 0
