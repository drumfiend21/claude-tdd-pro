# Standards source manifest — YAML / JSON / MD corpora

Source of truth for the rule corpora seeded by PROPOSAL-003 (landed as
[ADR-0007](adr/0007-yaml-json-md-corpora-and-prose-judge.md); architecture
amendment **§28.24**). Each table is an input to `standards/initial-refresh.sh`
(source enumeration) and to the per-rule `provenance[]` registry. License
posture per ADR-0007 §6 / CTP-D-6: **mirror** permissive corpora (Apache/MIT/CC/BSD),
**config-only mirror** for copyleft tool configs (GPL), **cite-link only** for
gated/proprietary sources (AWS / Microsoft / CIS / Snyk / Atlassian / ISO).

These tables are lifted verbatim from the brief's §6. They are reference data,
not enforced rules; rules materialize per-wave into
`generated-code-quality-standards/<ns>/` with their own `provenance[]` pointing
back at these source IDs.

## YAML corpus — 75 sources

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| YAML 1.2.2 spec | YAML Language Dev Team | https://yaml.org/spec/1.2.2/ | HTML (stable) | Permissive — citable with attribution |
| YAML spec (raw MD) | yaml/yaml-spec | https://raw.githubusercontent.com/yaml/yaml-spec/main/spec/1.2.2/spec.md | RAW MD, pin by commit | MIT-style (per repo LICENSE) |
| yamllint default config | adrienverge/yamllint | https://raw.githubusercontent.com/adrienverge/yamllint/master/yamllint/conf/default.yaml | RAW YAML | GPLv3 (config-only mirror) |
| yamllint rules reference | yamllint | https://yamllint.readthedocs.io/en/stable/rules.html | HTML (Sphinx) | GPLv3 docs |
| K8s Pod Security Standards | kubernetes.io | https://kubernetes.io/docs/concepts/security/pod-security-standards/ | HTML (Hugo); source github.com/kubernetes/website | CC-BY 4.0 |
| K8s Configuration Best Practices | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/overview/ | HTML | CC-BY 4.0 |
| K8s Security Context | kubernetes.io | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ | HTML | CC-BY 4.0 |
| K8s RBAC | kubernetes.io | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ | HTML | CC-BY 4.0 |
| K8s Secrets | kubernetes.io | https://kubernetes.io/docs/concepts/configuration/secret/ | HTML | CC-BY 4.0 |
| CIS Kubernetes Benchmark | CIS | https://www.cisecurity.org/benchmark/kubernetes | PDF gated | CIS EULA — cite-link only |
| kube-linter checks | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/checks.md | RAW MD, pin by commit | Apache 2.0 |
| kube-linter templates | stackrox/kube-linter | https://raw.githubusercontent.com/stackrox/kube-linter/main/docs/generated/templates.md | RAW MD | Apache 2.0 |
| Polaris checks | FairwindsOps/polaris | https://github.com/FairwindsOps/polaris/tree/master/checks | RAW JSON-schema, pin by commit | Apache 2.0 |
| Polaris docs | polaris.docs.fairwinds.com | https://polaris.docs.fairwinds.com/checks/ | HTML (Docusaurus) | Apache 2.0 |
| kubeconform | yannh/kubeconform | https://github.com/yannh/kubeconform | RAW (README + schemas) | Apache 2.0 |
| Kubernetes JSON Schemas | yannh/kubernetes-json-schema | https://github.com/yannh/kubernetes-json-schema | RAW JSON schemas | Apache 2.0 |
| Kubescape regolibrary controls | kubescape/regolibrary | https://raw.githubusercontent.com/kubescape/regolibrary/master/controls/ | RAW JSON+Rego | Apache 2.0 |
| Kubescape frameworks (NSA/CIS/MITRE/SSDF mappings) | kubescape/regolibrary | https://github.com/kubescape/regolibrary/tree/master/frameworks | RAW JSON | Apache 2.0 |
| Helm chart best practices | helm.sh | https://helm.sh/docs/chart_best_practices/ | HTML (Hugo); source github.com/helm/helm-www | Apache 2.0 |
| Helm values best practices | helm.sh | https://helm.sh/docs/chart_best_practices/values/ | HTML | Apache 2.0 |
| Helm values.schema.json guide | helm.sh | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| Docker Compose spec | compose-spec/compose-spec | https://raw.githubusercontent.com/compose-spec/compose-spec/main/spec.md | RAW MD | Apache 2.0 |
| Compose file reference | docs.docker.com | https://docs.docker.com/reference/compose-file/ | HTML | Apache 2.0 docs |
| GitHub Actions workflow syntax | docs.github.com | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions | HTML; source github.com/github/docs | CC-BY 4.0 |
| GHA security hardening | docs.github.com | https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions | HTML | CC-BY 4.0 |
| GHA secure-use reference | docs.github.com | https://docs.github.com/en/actions/reference/security/secure-use | HTML | CC-BY 4.0 |
| GHA OIDC w/ AWS | docs.github.com | https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services | HTML | CC-BY 4.0 |
| GHA concurrency | docs.github.com | https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency | HTML | CC-BY 4.0 |
| GitLab CI YAML reference | docs.gitlab.com | https://docs.gitlab.com/ci/yaml/ | HTML | CC-BY-SA 4.0 |
| GitLab CI job rules | docs.gitlab.com | https://docs.gitlab.com/ci/jobs/job_rules/ | HTML | CC-BY-SA 4.0 |
| Azure Pipelines YAML schema | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/ | HTML (server-rendered) | MS proprietary — cite-link |
| Azure Pipelines templates-for-security | learn.microsoft.com | https://learn.microsoft.com/en-us/azure/devops/pipelines/security/templates | HTML | MS proprietary |
| CircleCI config reference | circleci.com | https://circleci.com/docs/configuration-reference/ | HTML; source github.com/circleci/circleci-docs (Apache 2.0) | docs Apache 2.0 |
| Bitbucket Pipelines config ref | atlassian.com | https://support.atlassian.com/bitbucket-cloud/docs/bitbucket-pipelines-configuration-reference/ | HTML | Atlassian copyright — cite-link |
| Jenkins Pipeline-as-YAML | jenkins.io | https://plugins.jenkins.io/pipeline-as-yaml/ | HTML | MIT (plugin) |
| ansible-lint rules | docs.ansible.com | https://docs.ansible.com/projects/lint/rules/ | HTML (Sphinx) | GPLv3 + CC-BY |
| ansible-lint repo rules | ansible/ansible-lint | https://github.com/ansible/ansible-lint/tree/main/src/ansiblelint/rules | RAW Python+MD | GPLv3 |
| Ansible best practices | docs.ansible.com | https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html | HTML | GPLv3 + CC-BY |
| CloudFormation best practices | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html | HTML | AWS proprietary — cite-link |
| CFN template anatomy | docs.aws.amazon.com | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | AWS proprietary |
| OpenAPI 3.1 spec | OAI/OpenAPI-Specification | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | RAW MD | Apache 2.0 |
| OpenAPI 3.0.4 spec | OAI | https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.0.4.md | RAW MD | Apache 2.0 |
| Argo CD sync waves | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ | HTML (Sphinx); source github.com/argoproj/argo-cd/tree/master/docs/user-guide | Apache 2.0 |
| Argo CD sync options | argo-cd.readthedocs.io | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/ | HTML | Apache 2.0 |
| Flux Kustomize API v1 | fluxcd.io | https://fluxcd.io/flux/components/kustomize/api/v1/ | HTML (Hugo); source github.com/fluxcd/website | Apache 2.0 |
| Flux Kustomization spec | fluxcd.io | https://fluxcd.io/flux/components/kustomize/kustomizations/ | HTML | Apache 2.0 |
| Kustomize patches docs | kubernetes.io | https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ | HTML | CC-BY 4.0 |
| Sealed Secrets | bitnami-labs/sealed-secrets | https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/main/README.md | RAW MD | Apache 2.0 |
| SOPS | getsops/sops | https://raw.githubusercontent.com/getsops/sops/main/README.rst | RAW rST | MPL 2.0 |
| Prometheus config | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/configuration/ | HTML (Hugo); source github.com/prometheus/docs | Apache 2.0 + docs CC-BY-4.0 |
| Prometheus alerting rules | prometheus.io | https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/ | HTML | Apache 2.0 |
| OTel Collector configuration | open-telemetry/opentelemetry.io | https://raw.githubusercontent.com/open-telemetry/opentelemetry.io/main/content/en/docs/collector/configuration.md | RAW MD | CC-BY 4.0 |
| Istio VirtualService | istio.io | https://istio.io/latest/docs/reference/config/networking/virtual-service/ | HTML (Hugo); source github.com/istio/istio.io | Apache 2.0 |
| Istio DestinationRule | istio.io | https://istio.io/latest/docs/reference/config/networking/destination-rule/ | HTML | Apache 2.0 |
| Envoy config reference | envoyproxy.io | https://www.envoyproxy.io/docs/envoy/latest/configuration/configuration | HTML (Sphinx) | Apache 2.0 |
| Kong declarative config | docs.konghq.com | https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/ | HTML | Apache 2.0 docs |
| OWASP CI/CD Top 10 | OWASP | https://github.com/OWASP/www-project-top-10-ci-cd-security-risks | RAW MD + HTML | CC-BY-SA 4.0 |
| OWASP CI/CD Cheat Sheet | OWASP/CheatSheetSeries | https://raw.githubusercontent.com/OWASP/CheatSheetSeries/master/cheatsheets/CI_CD_Security_Cheat_Sheet.md | RAW MD | CC-BY-SA 4.0 |
| OWASP API Security Top 10 (2023) | OWASP/API-Security | https://github.com/OWASP/API-Security | RAW MD | CC-BY-SA 4.0 |
| OpenSSF Scorecard checks | ossf/scorecard | https://raw.githubusercontent.com/ossf/scorecard/main/docs/checks.md | RAW MD | Apache 2.0 |
| SLSA v1.0 requirements | slsa.dev | https://slsa.dev/spec/v1.0/requirements | HTML (Hugo) | CC-BY 4.0 |
| SLSA security levels | slsa.dev | https://slsa.dev/spec/v1.0/levels | HTML | CC-BY 4.0 |
| NIST SP 800-218 SSDF v1.1 | NIST | https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf | PDF | US Gov public domain |
| Checkov policy index — all | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/all.md | RAW MD | Apache 2.0 |
| Checkov K8s policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/kubernetes.md | RAW MD | Apache 2.0 |
| Checkov GitHub Actions policies | bridgecrewio/checkov | https://raw.githubusercontent.com/bridgecrewio/checkov/main/docs/5.Policy%20Index/github_actions.md | RAW MD | Apache 2.0 |
| Trivy checks bundle | aquasecurity/trivy-checks | https://github.com/aquasecurity/trivy-checks | RAW Rego + MD | Apache 2.0 |
| Trivy misconfig docs | trivy.dev | https://trivy.dev/latest/docs/scanner/misconfiguration/ | HTML (MkDocs) | Apache 2.0 |
| conftest | open-policy-agent/conftest | https://raw.githubusercontent.com/open-policy-agent/conftest/master/README.md | RAW MD | Apache 2.0 |
| Snyk K8s IaC rules | snyk.io | https://snyk.io/security-rules/kubernetes/deployment | HTML (Next.js partial-SPA) | Snyk copyright — cite-link |
| OpenGitOps principles | open-gitops/documents | https://raw.githubusercontent.com/open-gitops/documents/main/PRINCIPLES.md | RAW MD | Apache 2.0 |
| Google styleguide repo | google/styleguide | https://github.com/google/styleguide | RAW + GH Pages | Apache 2.0 |
| OpenShift security hardening | docs.openshift.com | https://docs.openshift.com/container-platform/latest/security/container_security/security-hardening.html | HTML | Red Hat docs CC-BY-SA |

(Plus ~5 secondary references — bram.us Norway-problem article, InfoWorld YAML gotchas — citation-only.)

## JSON corpus — 40+ sources

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| RFC 8259 (JSON spec) | IETF | https://datatracker.ietf.org/doc/html/rfc8259 + https://www.rfc-editor.org/rfc/rfc8259.txt | HTML / TXT (stable) | IETF Trust (public) |
| ECMA-404 (2nd ed) | ECMA International | https://ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf | PDF (stable) | ECMA RF |
| RFC 7493 (I-JSON) | IETF | https://datatracker.ietf.org/doc/html/rfc7493 | HTML / TXT | IETF Trust |
| JSON Schema 2020-12 | json-schema.org | https://json-schema.org/draft/2020-12/release-notes | HTML | BSD-2-Clause (per repo) |
| JSON Schema Draft 7 meta-schema | json-schema.org | http://json-schema.org/draft-07/schema# | JSON (stable) | BSD-2-Clause |
| Ajv (JSON Schema validator, JS) | ajv-validator/ajv | https://github.com/ajv-validator/ajv | git / raw | MIT |
| python-jsonschema | python-jsonschema/jsonschema | https://github.com/python-jsonschema/jsonschema | git / raw | MIT |
| OpenAPI 3.1 spec | OAI | https://spec.openapis.org/oas/v3.1.0.html + raw at https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/versions/3.1.0.md | HTML / RAW MD | Apache 2.0 |
| JSON-LD 1.1 | W3C | https://www.w3.org/TR/json-ld11/ | HTML | W3C Document License |
| JSON:API 1.1 | jsonapi.org | https://jsonapi.org/format/ | HTML | CC0 |
| JSON-RPC 2.0 | JSON-RPC WG | https://www.jsonrpc.org/specification | HTML | Perpetual implementation grant |
| RFC 7519 (JWT) | IETF | https://datatracker.ietf.org/doc/html/rfc7519 | HTML / TXT | IETF Trust |
| RFC 7515 (JWS) | IETF | https://datatracker.ietf.org/doc/html/rfc7515 | HTML / TXT | IETF Trust |
| RFC 7516 (JWE) | IETF | https://datatracker.ietf.org/doc/html/rfc7516 | HTML / TXT | IETF Trust |
| RFC 7517 (JWK) | IETF | https://datatracker.ietf.org/doc/html/rfc7517 | HTML / TXT | IETF Trust |
| **RFC 8725 (JWT BCP)** | IETF | https://datatracker.ietf.org/doc/html/rfc8725 | HTML / TXT | IETF Trust |
| package.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-json | HTML | proprietary (de-facto spec) |
| package-lock.json reference | npm | https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json | HTML | proprietary |
| composer.lock | Composer | https://getcomposer.org/doc/01-basic-usage.md | RAW MD | MIT |
| Pipfile.lock | PyPA / Pipenv | https://pipenv.pypa.io/en/latest/pipfile.html | HTML | MIT |
| tsconfig.json | Microsoft (TypeScript) | https://www.typescriptlang.org/tsconfig | HTML | Apache 2.0 project / proprietary docs |
| VS Code settings/launch/tasks | Microsoft | https://code.visualstudio.com/docs/configure/settings | HTML | proprietary docs |
| AWS IAM Policy grammar | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_grammar.html | HTML | proprietary — cite-link |
| AWS IAM best practices | AWS | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html | HTML | proprietary |
| GCP IAM allow-policy | Google Cloud | https://cloud.google.com/iam/docs/policies | HTML | proprietary |
| Azure RBAC role definitions | Microsoft | https://learn.microsoft.com/en-us/azure/role-based-access-control/role-definitions | HTML; source MicrosoftDocs/azure-docs-pr | CC-BY 4.0 (docs) |
| Azure Policy definition structure | Microsoft | https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics | HTML | CC-BY 4.0 |
| Kubernetes JSON manifests | Kubernetes | https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/ | HTML | CC-BY 4.0 |
| Helm values.schema.json | Helm | https://helm.sh/docs/topics/charts/#schema-files | HTML | Apache 2.0 |
| devcontainer.json | containers.dev (Microsoft + community) | https://containers.dev/implementors/json_reference/ + https://github.com/devcontainers/spec/blob/main/schemas/devContainer.base.schema.json | HTML / RAW | MIT |
| Renovate config | Mend/Renovate | https://docs.renovatebot.com/configuration-options/ + https://docs.renovatebot.com/renovate-schema.json | HTML / RAW JSON | AGPL-3.0 (project) |
| CloudFormation JSON template | AWS | https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html | HTML | proprietary |
| Terraform JSON syntax | HashiCorp | https://developer.hashicorp.com/terraform/language/syntax/json | HTML | MPL 2.0 project |
| Pulumi state | Pulumi | https://www.pulumi.com/docs/iac/concepts/state-and-backends/ | HTML | Apache 2.0 |
| OPA bundle manifest | OPA | https://www.openpolicyagent.org/docs/management-bundles#bundle-file-format | HTML | Apache 2.0 |
| **CycloneDX SBOM JSON** | OWASP / ECMA TC54 | https://cyclonedx.org/specification/overview/ + https://github.com/CycloneDX/specification/tree/master/schema | HTML / RAW JSON | Apache 2.0 + ECMA RF |
| **SPDX JSON 2.3** | Linux Foundation / SPDX | https://spdx.github.io/spdx-spec/v2.3/ + https://github.com/spdx/spdx-spec/blob/support/2.3.1/schemas/spdx-schema.json | HTML / RAW JSON | CC-BY-3.0 |
| **SARIF 2.1.0** | OASIS | https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html + https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json | HTML / RAW JSON | OASIS RF |
| OTel JSON (OTLP file) | OpenTelemetry | https://opentelemetry.io/docs/specs/otlp/ | HTML | Apache 2.0 |
| CloudEvents JSON 1.0.2 | CNCF | https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/formats/json-format.md | RAW MD | Apache 2.0 |
| Schema.org JSON-LD context | Schema.org | https://schema.org/docs/jsonldcontext.json | RAW JSON | CC-BY-SA 3.0 |
| Elastic Common Schema (ECS) | Elastic | https://www.elastic.co/docs/reference/ecs | HTML | Apache 2.0 |
| Spectral (OAS linter) | Stoplight | https://github.com/stoplightio/spectral | git / raw | Apache 2.0 |
| cfn-lint | AWS | https://github.com/aws-cloudformation/cfn-lint | git / raw | Apache 2.0 |
| **SchemaStore — meta-catalog of 700+ JSON Schemas** | SchemaStore.org | https://www.schemastore.org/json/ + https://github.com/SchemaStore/schemastore | git / raw | Apache 2.0 |

## MD corpus — 40 sources, two layers

### Layer 1 — syntactic

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| CommonMark 0.31.2 | John MacFarlane | https://spec.commonmark.org/0.31.2/ + repo raw `spec.txt` | HTML / RAW | CC-BY-SA 4.0 |
| GitHub Flavored Markdown | GitHub | https://github.github.com/gfm/ | HTML | CC-BY-SA 4.0 |
| markdownlint rules MD001..MD060 | David Anson | https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md | RAW MD | MIT |
| remark-lint | unified collective | https://github.com/remarkjs/remark-lint | RAW MD | MIT |
| Vale | jdkato | https://vale.sh + repo | RAW + HTML | MIT |
| Vale styles (Google / Microsoft / write-good / alex / proselint) | errata-ai | https://github.com/errata-ai | RAW YAML | mixed per package |
| alex (inclusive language) | get-alex/alex | https://github.com/get-alex/alex | RAW | MIT |
| write-good | btford/write-good | https://github.com/btford/write-good | RAW | MIT |
| proselint | amperser/proselint | https://github.com/amperser/proselint | RAW | BSD-3-Clause |
| textlint | textlint | https://github.com/textlint/textlint | RAW | MIT |
| retext (equality, profanities, simplify, passive) | retextjs | https://github.com/retextjs | RAW | MIT |
| markdown-link-check | tcort | https://github.com/tcort/markdown-link-check | RAW | ISC |
| lychee link checker | lycheeverse | https://github.com/lycheeverse/lychee | RAW | Apache-2.0 OR MIT |
| Hugo front matter | Hugo | https://gohugo.io/content-management/front-matter/ | HTML | Apache-2.0 (docs) |
| Jekyll front matter | Jekyll | https://jekyllrb.com/docs/front-matter/ | HTML | MIT |
| Docusaurus markdown features | Meta | https://docusaurus.io/docs/markdown-features | HTML | MIT |
| Mermaid spec | mermaid-js | https://mermaid.js.org/intro/ | HTML + RAW | MIT |
| PlantUML | PlantUML | https://plantuml.com/ | HTML | GPL engine / docs CC |
| REUSE 3.3 spec (SPDX headers) | FSFE | https://reuse.software/spec-3.3/ | HTML | CC-BY-SA 4.0 |
| cspell | streetsidesoftware | https://github.com/streetsidesoftware/cspell | RAW | MIT |
| codespell | codespell-project | https://github.com/codespell-project/codespell | RAW | GPL-2.0 (dicts CC-BY-SA-3.0) |

### Layer 2 — semantic / prose-as-code

| Context | Org | URL | Refreshable? | License |
|---|---|---|---|---|
| RFC 2119 (keyword authority) | IETF | https://www.rfc-editor.org/rfc/rfc2119 | HTML / TXT | IETF Trust |
| RFC 8174 (case-sensitivity clarification) | IETF | https://www.rfc-editor.org/rfc/rfc8174 | HTML / TXT | IETF Trust |
| MADR 4.0 ADR template | adr/madr | https://adr.github.io/madr/ + repo raw | HTML / RAW | MIT OR CC0-1.0 |
| ADR template catalog (Nygard / Y-Statements / Planguage / Alexandrian) | joelparkerhenderson | https://github.com/joelparkerhenderson/architecture-decision-record | RAW | MIT |
| Y-Statements | Olaf Zimmermann | https://medium.com/olzzio/y-statements-10eb07b5a177 (mirror in catalog above) | HTML | CC-BY (article) |
| arc42 (12-section template) | Hruschka + Starke | https://arc42.org/overview + GitHub templates | HTML / RAW | CC-BY-SA 4.0 |
| C4 model | Simon Brown | https://c4model.com/ | HTML | CC-BY 4.0 |
| ISO/IEC/IEEE 42010:2022 | ISO | https://www.iso.org/standard/74393.html | PAYWALL | proprietary — use arc42 + C4 surrogates |
| Diátaxis framework | Daniele Procida | https://diataxis.fr/ | HTML | CC-BY-SA 4.0 |
| Write the Docs guide | community | https://www.writethedocs.org/guide/ | HTML | CC-BY 4.0 |
| Google developer docs style guide | Google | https://developers.google.com/style | HTML | CC-BY 4.0 |
| Microsoft Writing Style Guide | Microsoft | https://learn.microsoft.com/en-us/style-guide/welcome/ + MicrosoftDocs/microsoft-style-guide-pr | HTML / RAW | proprietary but linkable |
| standard-readme spec | Richard Littauer | https://github.com/RichardLitt/standard-readme | RAW | MIT |
| Make a README | Danny Guo | https://www.makeareadme.com/ | HTML | MIT |
| GitHub open-source-guide | GitHub | https://opensource.guide/ + github/opensource.guide | HTML / RAW | CC-BY 4.0 |
| Conventional Commits 1.0.0 | OpenJS | https://www.conventionalcommits.org/en/v1.0.0/ | HTML | CC-BY 3.0 |
| Keep a Changelog 1.1.0 | Olivier Lacan | https://keepachangelog.com/en/1.1.0/ | HTML | MIT |
| SemVer 2.0.0 | Tom Preston-Werner | https://semver.org/spec/v2.0.0.html | HTML | CC-BY 3.0 |
| Contributor Covenant 2.1 | Org. for Ethical Source | https://www.contributor-covenant.org/version/2/1/code_of_conduct/ | HTML + RAW | CC-BY 4.0 |
| OWASP STRIDE (threat modeling) | OWASP | https://owasp.org/www-community/Threat_Modeling_Process | HTML | CC-BY-SA 4.0 |
| LINDDUN (privacy threat modeling) | KU Leuven DistriNet | https://www.linddun.org/ | HTML | CC-BY (educational) |
| GitHub Advisory Database (OSV) | GitHub | https://github.com/github/advisory-database | RAW | CC-BY 4.0 |
