#!/usr/bin/env bash
# commands/promote-config-rules.sh - promote the PROPOSAL-003 / ADR-0007 config &
# markup corpora (YAML/JSON family namespaces) into first-class, grounded, ESLint-style
# detector rules (S-7 promotion; §28.24 Waves 1-3).
#
# Mirrors commands/promote-cloud-rules.sh exactly, but for the brief's namespaces
# (k8s, helm, compose, CI/CD, IaC, iam, jwt, sbom, sarif, oas, gitops, observability,
# mesh, arch, ...). The literal require/forbid security & quality rules run via the
# SAME shared §2.2 detector rubric/detectors/cloud-guidance-rule.sh; their check
# manifest is emitted to rubric/detectors/config-guidance-rules.json (a SECOND manifest
# the detector + enforce.sh merge alongside cloud-guidance-rules.json, so the two
# generators never clobber each other). Each rule cites an authoritative source
# (provenance) from docs/standards-source-manifest.md. Deterministic + idempotent.
#
# Syntactic namespaces (yaml/json/md) ship via their own Layer-1 wrapper detectors
# (yaml-syntax.sh / json-schema.sh / md-structure.sh), authored separately.
#
# CLI: [--root <dir>] (default plugin root)   exit 0 ok / 2 usage.

set -uo pipefail
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2-}"; shift 2 ;;
    -h|--help) echo "Usage: promote-config-rules.sh [--root <dir>]" >&2; exit 0 ;;
    *) echo "promote-config-rules: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$ROOT" ] && ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"

ROOT="$ROOT" ruby -ryaml -rjson -rdigest -rfileutils -e '
  Encoding.default_external = Encoding::UTF_8
  root = ENV["ROOT"]

  # single source of truth: per-namespace authority + grounded detector rules.
  # rule = [id, name, description, token, mode, applies, source_id, severity, type]
  NS = [
    { ns: "k8s", sid: "k8s-pod-security-standards", pub: "Kubernetes / kube-linter",
      url: "https://kubernetes.io/docs/concepts/security/pod-security-standards/",
      lic: "Reference/educational use - Kubernetes docs CC-BY 4.0; kube-linter Apache 2.0",
      rules: [
        ["g-k8s-no-privileged-container","no-privileged-container","Containers must not run in privileged mode; a privileged container shares the host kernel namespaces.","privileged: true","forbid","*.yaml,*.yml","k8s-pod-security-standards","P0","problem"],
        ["g-k8s-no-host-network","no-host-network","Pods must not share the host network namespace (hostNetwork).","hostNetwork: true","forbid","*.yaml,*.yml","k8s-pod-security-standards","P0","problem"],
        ["g-k8s-no-host-pid","no-host-pid","Pods must not share the host PID namespace (hostPID).","hostPID: true","forbid","*.yaml,*.yml","k8s-pod-security-standards","P0","problem"],
        ["g-k8s-no-host-ipc","no-host-ipc","Pods must not share the host IPC namespace (hostIPC).","hostIPC: true","forbid","*.yaml,*.yml","k8s-pod-security-standards","P0","problem"],
        ["g-k8s-no-allow-privilege-escalation","no-allow-privilege-escalation","Containers must set allowPrivilegeEscalation to false.","allowPrivilegeEscalation: true","forbid","*.yaml,*.yml","k8s-pod-security-standards","P1","problem"],
        ["g-k8s-no-latest-image-tag","no-latest-image-tag","Container images must be pinned to an explicit tag or digest, never :latest.",":latest","forbid","*.yaml,*.yml","k8s-pod-security-standards","P1","problem"],
        ["g-k8s-run-as-non-root","run-as-non-root","Pods and containers must declare runAsNonRoot so they do not run as uid 0.","runAsNonRoot","require","*.yaml,*.yml","k8s-pod-security-standards","P1","problem"],
        ["g-k8s-set-resource-limits","set-resource-limits","Containers must declare resource requests and limits.","resources:","require","*.yaml,*.yml","k8s-pod-security-standards","P2","suggestion"],
        ["g-k8s-read-only-root-filesystem","read-only-root-filesystem","Containers should mount their root filesystem read-only.","readOnlyRootFilesystem","require","*.yaml,*.yml","k8s-pod-security-standards","P2","suggestion"],
        ["g-k8s-drop-all-capabilities","drop-all-capabilities","Containers must drop Linux capabilities they do not need.","drop:","require","*.yaml,*.yml","k8s-pod-security-standards","P2","suggestion"],
      ] },
    { ns: "helm", sid: "helm-best-practices", pub: "Helm",
      url: "https://helm.sh/docs/chart_best_practices/",
      lic: "Reference/educational use - Helm docs Apache 2.0",
      rules: [
        ["g-helm-no-latest-tag","no-latest-tag","Chart values must pin image tags, never :latest.",":latest","forbid","*.yaml,*.tpl","helm-best-practices","P1","problem"],
        ["g-helm-declare-resources","declare-resources","Chart values should declare container resources.","resources:","require","values.yaml","helm-best-practices","P2","suggestion"],
        ["g-helm-provide-values-schema","provide-values-schema","Charts should ship a values.schema.json to validate operator input.","$schema","require","values.schema.json","helm-best-practices","P3","suggestion"],
      ] },
    { ns: "compose", sid: "compose-spec", pub: "Compose Spec / Docker",
      url: "https://docs.docker.com/reference/compose-file/",
      lic: "Reference/educational use - Compose Spec Apache 2.0",
      rules: [
        ["g-compose-no-privileged","no-privileged","Compose services must not run privileged.","privileged: true","forbid","docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml","compose-spec","P0","problem"],
        ["g-compose-no-host-network","no-host-network","Compose services must not use host network mode.","network_mode: host","forbid","docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml","compose-spec","P1","problem"],
        ["g-compose-pin-image-tag","pin-image-tag","Compose images must be pinned, never :latest.",":latest","forbid","docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml","compose-spec","P1","problem"],
        ["g-compose-no-host-pid","no-host-pid","Compose services must not share the host PID namespace.","pid: host","forbid","docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml","compose-spec","P1","problem"],
        ["g-compose-drop-capabilities","drop-capabilities","Compose services should drop unneeded Linux capabilities.","cap_drop","require","docker-compose.yml,docker-compose.yaml,compose.yml,compose.yaml","compose-spec","P2","suggestion"],
      ] },
    { ns: "gha", sid: "gha-security-hardening", pub: "GitHub",
      url: "https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions",
      lic: "Reference/educational use - GitHub docs CC-BY 4.0",
      rules: [
        ["g-gha-no-pull-request-target","no-pull-request-target","Workflows must avoid pull_request_target with untrusted checkout (privilege-escalation sink).","pull_request_target","forbid",".github/workflows/*.yml,.github/workflows/*.yaml","gha-security-hardening","P1","problem"],
        ["g-gha-pin-actions-to-sha","pin-actions-to-sha","Third-party actions must be pinned to a full commit SHA, not a mutable @master ref.","@master","forbid",".github/workflows/*.yml,.github/workflows/*.yaml","gha-security-hardening","P1","problem"],
        ["g-gha-no-unpinned-main-ref","no-unpinned-main-ref","Third-party actions must not reference a mutable @main ref.","@main","forbid",".github/workflows/*.yml,.github/workflows/*.yaml","gha-security-hardening","P1","problem"],
        ["g-gha-set-minimal-permissions","set-minimal-permissions","Workflows must declare a minimal permissions block for GITHUB_TOKEN.","permissions:","require",".github/workflows/*.yml,.github/workflows/*.yaml","gha-security-hardening","P2","suggestion"],
        ["g-gha-no-script-injection","no-script-injection","Workflows must not interpolate untrusted issue/PR titles directly into run scripts.","${{ github.event.issue.title }}","forbid",".github/workflows/*.yml,.github/workflows/*.yaml","gha-security-hardening","P1","problem"],
      ] },
    { ns: "glci", sid: "gitlab-ci-yaml", pub: "GitLab",
      url: "https://docs.gitlab.com/ci/yaml/",
      lic: "Reference/educational use - GitLab docs CC-BY-SA 4.0",
      rules: [
        ["g-glci-pin-image-tag","pin-image-tag","GitLab CI job images must be pinned, never :latest.",":latest","forbid",".gitlab-ci.yml,.gitlab-ci.yaml","gitlab-ci-yaml","P1","problem"],
        ["g-glci-declare-stages","declare-stages","Pipelines should declare an explicit stages list for ordering.","stages:","require",".gitlab-ci.yml,.gitlab-ci.yaml","gitlab-ci-yaml","P3","suggestion"],
        ["g-glci-no-interruptible-disabled","no-interruptible-disabled","Jobs should remain interruptible to save runners on superseded pipelines.","interruptible: false","forbid",".gitlab-ci.yml,.gitlab-ci.yaml","gitlab-ci-yaml","P3","suggestion"],
      ] },
    { ns: "azdo", sid: "azure-pipelines-yaml", pub: "Microsoft",
      url: "https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/",
      lic: "Reference/educational use - (c) Microsoft (cite-link)",
      rules: [
        ["g-azdo-pin-image-tag","pin-image-tag","Pipeline container images must be pinned, never :latest.",":latest","forbid","azure-pipelines.yml,azure-pipelines.yaml","azure-pipelines-yaml","P1","problem"],
        ["g-azdo-no-plaintext-secret","no-plaintext-secret","Pipelines must not declare plaintext passwords; use secret variables.","password:","forbid","azure-pipelines.yml,azure-pipelines.yaml","azure-pipelines-yaml","P2","problem"],
      ] },
    { ns: "circleci", sid: "circleci-config", pub: "CircleCI",
      url: "https://circleci.com/docs/configuration-reference/",
      lic: "Reference/educational use - CircleCI docs Apache 2.0",
      rules: [
        ["g-circleci-pin-image-tag","pin-image-tag","Executor images must be pinned, never :latest.",":latest","forbid",".circleci/config.yml,.circleci/config.yaml","circleci-config","P1","problem"],
        ["g-circleci-pin-orb-version","pin-orb-version","Orbs must be pinned to an explicit version, not @volatile.","@volatile","forbid",".circleci/config.yml,.circleci/config.yaml","circleci-config","P1","problem"],
      ] },
    { ns: "bbp", sid: "bitbucket-pipelines", pub: "Atlassian",
      url: "https://support.atlassian.com/bitbucket-cloud/docs/bitbucket-pipelines-configuration-reference/",
      lic: "Reference/educational use - (c) Atlassian (cite-link)",
      rules: [
        ["g-bbp-pin-image-tag","pin-image-tag","Pipeline images must be pinned, never :latest.",":latest","forbid","bitbucket-pipelines.yml,bitbucket-pipelines.yaml","bitbucket-pipelines","P1","problem"],
        ["g-bbp-no-plaintext-secret","no-plaintext-secret","Pipelines must not declare plaintext passwords; use secured variables.","password:","forbid","bitbucket-pipelines.yml,bitbucket-pipelines.yaml","bitbucket-pipelines","P2","problem"],
      ] },
    { ns: "jenkins", sid: "jenkins-pipeline", pub: "Jenkins",
      url: "https://plugins.jenkins.io/pipeline-as-yaml/",
      lic: "Reference/educational use - Jenkins plugin MIT",
      rules: [
        ["g-jenkins-pin-image-tag","pin-image-tag","Agent images must be pinned, never :latest.",":latest","forbid","Jenkinsfile,*.jenkinsfile","jenkins-pipeline","P1","problem"],
        ["g-jenkins-no-plaintext-credentials","no-plaintext-credentials","Pipelines must not embed plaintext passwords; use the credentials() binding.","password:","forbid","Jenkinsfile,*.jenkinsfile","jenkins-pipeline","P2","problem"],
      ] },
    { ns: "ansible", sid: "ansible-lint-rules", pub: "Ansible",
      url: "https://docs.ansible.com/projects/lint/rules/",
      lic: "Reference/educational use - ansible-lint GPLv3 + CC-BY",
      rules: [
        ["g-ansible-no-plaintext-password","no-plaintext-password","Plays must not set ansible_password in plaintext; use Vault.","ansible_password:","forbid","*.yml,*.yaml","ansible-lint-rules","P1","problem"],
        ["g-ansible-no-validate-certs-disabled","no-validate-certs-disabled","Modules must not disable TLS certificate validation.","validate_certs: false","forbid","*.yml,*.yaml","ansible-lint-rules","P1","problem"],
        ["g-ansible-pin-package-version","pin-package-version","Package installs should pin a version rather than tracking latest.",":latest","forbid","*.yml,*.yaml","ansible-lint-rules","P2","suggestion"],
      ] },
    { ns: "cfn", sid: "cfn-best-practices", pub: "AWS",
      url: "https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html",
      lic: "Reference/educational use - (c) AWS (cite-link)",
      rules: [
        ["g-cfn-no-wildcard-iam-action","no-wildcard-iam-action","CloudFormation IAM policies must not grant Action: *.","\"Action\": \"*\"","forbid","*.cfn.yaml,*.cfn.json,*.template","cfn-best-practices","P0","problem"],
        ["g-cfn-no-public-read-bucket","no-public-read-bucket","S3 buckets must not be declared PublicRead.","PublicRead","forbid","*.cfn.yaml,*.cfn.json,*.template","cfn-best-practices","P1","problem"],
        ["g-cfn-no-hardcoded-password","no-hardcoded-password","Templates must not hardcode passwords; use Secrets Manager or NoEcho parameters.","Password:","forbid","*.cfn.yaml,*.cfn.json,*.template","cfn-best-practices","P2","problem"],
      ] },
    { ns: "oas", sid: "openapi-spec", pub: "OpenAPI Initiative",
      url: "https://spec.openapis.org/oas/v3.1.0.html",
      lic: "Reference/educational use - OpenAPI Spec Apache 2.0",
      rules: [
        ["g-oas-declare-security-schemes","declare-security-schemes","APIs must declare securitySchemes so endpoints can require auth.","securitySchemes","require","openapi.yaml,openapi.json,swagger.yaml,swagger.json","openapi-spec","P1","problem"],
        ["g-oas-no-plaintext-http-server","no-plaintext-http-server","API server URLs must use https, not plaintext http.","http://","forbid","openapi.yaml,openapi.json,swagger.yaml,swagger.json","openapi-spec","P2","problem"],
        ["g-oas-declare-spec-version","declare-spec-version","Documents must declare the openapi version field.","openapi:","require","openapi.yaml,swagger.yaml","openapi-spec","P3","suggestion"],
      ] },
    { ns: "gitops", sid: "opengitops-principles", pub: "OpenGitOps / Argo / Flux",
      url: "https://raw.githubusercontent.com/open-gitops/documents/main/PRINCIPLES.md",
      lic: "Reference/educational use - OpenGitOps Apache 2.0",
      rules: [
        ["g-gitops-pin-target-revision","pin-target-revision","Argo CD Applications must pin targetRevision, not track mutable HEAD.","targetRevision: HEAD","forbid","*.yaml,*.yml","opengitops-principles","P1","problem"],
        ["g-gitops-no-plaintext-secret","no-plaintext-secret","GitOps repos must not commit raw Secret manifests; use SealedSecret/SOPS.","kind: Secret","forbid","*.yaml,*.yml","opengitops-principles","P2","problem"],
      ] },
    { ns: "observability", sid: "prometheus-config", pub: "Prometheus / OpenTelemetry",
      url: "https://prometheus.io/docs/prometheus/latest/configuration/configuration/",
      lic: "Reference/educational use - Prometheus Apache 2.0 + docs CC-BY 4.0",
      rules: [
        ["g-observability-no-insecure-endpoint","no-insecure-endpoint","Collector/exporter endpoints must not disable TLS via insecure: true.","insecure: true","forbid","*.yaml,*.yml","prometheus-config","P1","problem"],
        ["g-observability-define-alerting","define-alerting","Monitoring config should define alerting rules, not only scrape.","alert:","require","*.rules.yml,*.rules.yaml,prometheus.yml","prometheus-config","P2","suggestion"],
      ] },
    { ns: "mesh", sid: "istio-config", pub: "Istio / Envoy",
      url: "https://istio.io/latest/docs/reference/config/networking/virtual-service/",
      lic: "Reference/educational use - Istio docs Apache 2.0",
      rules: [
        ["g-mesh-no-mtls-disabled","no-mtls-disabled","PeerAuthentication must not DISABLE mutual TLS.","mode: DISABLE","forbid","*.yaml,*.yml","istio-config","P1","problem"],
        ["g-mesh-no-wildcard-host","no-wildcard-host","VirtualService/Gateway hosts must not be an open wildcard.","- \"*\"","forbid","*.yaml,*.yml","istio-config","P2","problem"],
      ] },
    { ns: "iac-linter", sid: "checkov-policy-index", pub: "Checkov / Trivy",
      url: "https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/all.md",
      lic: "Reference/educational use - Checkov/Trivy Apache 2.0",
      rules: [
        ["g-iac-linter-no-blanket-skip","no-blanket-skip","IaC linter config must not blanket-skip every check.","skip-check: \"*\"","forbid",".checkov.yaml,.checkov.yml,.trivy.yaml","checkov-policy-index","P2","problem"],
        ["g-iac-linter-no-soft-fail","no-soft-fail","IaC scanning must not be configured soft-fail (findings ignored).","soft_fail: true","forbid",".checkov.yaml,.checkov.yml,.trivy.yaml","checkov-policy-index","P2","problem"],
      ] },
    { ns: "iam", sid: "aws-iam-best-practices", pub: "AWS / GCP / Azure IAM",
      url: "https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html",
      lic: "Reference/educational use - (c) AWS (cite-link)",
      rules: [
        ["g-iam-no-wildcard-action","no-wildcard-action","IAM policies must not grant Action: * (least privilege).","\"Action\": \"*\"","forbid","*.json","aws-iam-best-practices","P0","problem"],
        ["g-iam-no-wildcard-resource","no-wildcard-resource","IAM policies must not grant Resource: * for write actions.","\"Resource\": \"*\"","forbid","*.json","aws-iam-best-practices","P0","problem"],
        ["g-iam-no-wildcard-principal","no-wildcard-principal","Resource policies must not grant Principal: * (anonymous access).","\"Principal\": \"*\"","forbid","*.json","aws-iam-best-practices","P0","problem"],
        ["g-iam-no-full-admin","no-full-admin","IAM statements must not grant the *:* full-admin action.","\"*:*\"","forbid","*.json","aws-iam-best-practices","P0","problem"],
      ] },
    { ns: "jwt", sid: "rfc-8725-jwt-bcp", pub: "IETF",
      url: "https://datatracker.ietf.org/doc/html/rfc8725",
      lic: "IETF Trust (public)",
      rules: [
        ["g-jwt-no-alg-none-compact","no-alg-none-compact","JWT config must not accept the unsecured alg none (RFC 8725).","\"alg\":\"none\"","forbid","*.json,*.yaml,*.yml","rfc-8725-jwt-bcp","P0","problem"],
        ["g-jwt-no-alg-none-spaced","no-alg-none-spaced","JWT config must not accept the unsecured alg none (RFC 8725).","\"alg\": \"none\"","forbid","*.json,*.yaml,*.yml","rfc-8725-jwt-bcp","P0","problem"],
        ["g-jwt-no-hardcoded-secret","no-hardcoded-secret","JWT signing secrets must not be hardcoded in config.","\"secret\":","forbid","*.json,*.yaml,*.yml","rfc-8725-jwt-bcp","P1","problem"],
      ] },
    { ns: "sbom", sid: "cyclonedx-spec", pub: "OWASP CycloneDX / SPDX",
      url: "https://cyclonedx.org/specification/overview/",
      lic: "Reference/educational use - CycloneDX Apache 2.0; SPDX CC-BY 3.0",
      rules: [
        ["g-sbom-declare-spec-version","declare-spec-version","SBOMs must declare their spec version (specVersion / spdxVersion).","specVersion","require","*.cdx.json,bom.json,sbom.json","cyclonedx-spec","P2","problem"],
        ["g-sbom-include-components","include-components","SBOMs must enumerate components/packages.","components","require","*.cdx.json,bom.json,sbom.json","cyclonedx-spec","P2","problem"],
      ] },
    { ns: "sarif", sid: "sarif-2-1-0", pub: "OASIS",
      url: "https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html",
      lic: "OASIS RF",
      rules: [
        ["g-sarif-declare-version","declare-version","SARIF logs must declare version 2.1.0 (self-conformance).","\"version\": \"2.1.0\"","require","*.sarif,*.sarif.json","sarif-2-1-0","P2","problem"],
        ["g-sarif-include-runs","include-runs","SARIF logs must contain a runs array.","\"runs\"","require","*.sarif,*.sarif.json","sarif-2-1-0","P2","problem"],
        ["g-sarif-declare-schema","declare-schema","SARIF logs should reference the OASIS $schema.","$schema","require","*.sarif,*.sarif.json","sarif-2-1-0","P3","suggestion"],
      ] },
    { ns: "jsonschema", sid: "json-schema-2020-12", pub: "json-schema.org",
      url: "https://json-schema.org/draft/2020-12/release-notes",
      lic: "Reference/educational use - JSON Schema BSD-2-Clause",
      rules: [
        ["g-jsonschema-declare-schema","declare-schema","Schemas must declare the $schema dialect.","$schema","require","*.schema.json","json-schema-2020-12","P2","problem"],
        ["g-jsonschema-constrain-additional-properties","constrain-additional-properties","Object schemas should constrain additionalProperties.","additionalProperties","require","*.schema.json","json-schema-2020-12","P3","suggestion"],
      ] },
    { ns: "arch", sid: "madr-arc42", pub: "MADR / arc42 / C4",
      url: "https://adr.github.io/madr/",
      lic: "Reference/educational use - MADR MIT/CC0; arc42 CC-BY-SA 4.0",
      rules: [
        ["g-arch-no-tbd-placeholder","no-tbd-placeholder","Architecture docs must not ship unresolved TBD placeholders in place of a decision.","TBD","forbid","*.md","madr-arc42","P2","problem"],
        ["g-arch-no-fixme-marker","no-fixme-marker","Architecture docs must not ship FIXME markers in committed decisions.","FIXME","forbid","*.md","madr-arc42","P2","problem"],
        ["g-arch-no-decision-pending","no-decision-pending","An ADR must record a decision, not defer it with DECISION PENDING.","DECISION PENDING","forbid","*.md","madr-arc42","P2","problem"],
      ] },
  ]

  # §28.24 Wave-3 prose-as-code activation: these rules ALSO bind architectural prose
  # (an ADR/design doc proposing the violating design red-flags before code exists).
  PROSE = %w[
    g-iam-no-wildcard-action g-iam-no-full-admin
    g-jwt-no-alg-none-compact
    g-k8s-no-privileged-container g-k8s-no-host-network
    g-gha-no-pull-request-target
  ]

  manifest = { "rules" => {} }
  total = 0
  NS.each do |n|
    ids = n[:rules].map { |r| r[0] }
    doc = {}
    doc["source"] = {
      "id" => n[:sid],
      "authoritative_publisher" => n[:pub],
      "authoritative_url" => n[:url],
      "registry_link" => "STANDARDS-URLS.yaml",
      "fetched_at" => "2026-06-19T00:00:00Z",
      "content_hash" => "sha256:#{n[:ns]}-standards-placeholder-content-hash-for-bootstrap",
      "fetch_frequency" => "daily",
      "fragility_tier" => "medium",
      "license_note" => n[:lic],
    }
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
      if PROSE.include?(id)
        rule["applies_to_prose"] = true
        rule["applies_to_prose_kinds"] = ["architecture", "adr"]
      end
      rule
    end
    doc["recommended_set"] = ids
    doc["all_set"] = ids.dup
    total += ids.size

    dir = File.join(root, "generated-code-quality-standards", n[:ns])
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "#{n[:ns]}-standards.yaml")
    File.write(path, doc.to_yaml)
    STDERR.puts "promoted #{n[:ns]}: #{ids.size} rules -> #{path}"
  end

  File.write(File.join(root, "rubric", "detectors", "config-guidance-rules.json"),
             JSON.pretty_generate(manifest) + "\n")
  STDERR.puts "promote-config-rules: #{NS.size} namespaces activated, #{total} detector rules"
'
# Re-apply the ADR-0008 Wave 2 4-axis migration so re-generation never drops applies_to/enforced_by.
[ -x "$(dirname "$0")/migrate-rules-to-applies-to.sh" ] && \
  bash "$(dirname "$0")/migrate-rules-to-applies-to.sh" --root "$ROOT" >/dev/null 2>&1 || true
exit 0
