#!/usr/bin/env bash
# commands/toolchain-advisor.sh - S-45 implementation-toolchain advisor
# (v1.14 §27.16).
#
# Terraform/Bicep only provision infrastructure. This advisor recommends the
# rest of the toolchain needed to actually build, deploy, and operate the chosen
# architecture - per the selected option + platform - and (deterministically)
# scaffolds the parts that have a stable shape. Each recommendation is grounded
# where a secured source backs it (observability -> OpenTelemetry, gitops ->
# Argo CD, messaging -> Enterprise Integration Patterns, iac -> Terraform
# Recommended Practices, finops -> FinOps) and marked needs_grounding otherwise
# (cite-or-decline).
#
# CLI:
#   --handoff <json>       S-41 platform-handoff.json (platform + iac_targets)
#   --requirements <json>  S-33 technical-requirements.json (detects data/messaging needs)
#   --scaffold-dir <dir>   emit deterministic starter configs here (optional)
#   --out <json>           output (default standards/toolchain.json)
#   --now <iso> / --dry-run
#
# stderr: toolchain=<path> recommendations=<n> grounded=<g> needs_grounding=<n>
#         scaffolds=<s> platform=<p>
# Exit: 0 success / 2 usage error.

set -uo pipefail

HANDOFF=""; REQ=""; SCAFFOLD_DIR=""; OUT=""; NOW=""; DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --handoff)      HANDOFF="${2-}";      shift 2 ;;
    --requirements) REQ="${2-}";          shift 2 ;;
    --scaffold-dir) SCAFFOLD_DIR="${2-}"; shift 2 ;;
    --out)          OUT="${2-}";          shift 2 ;;
    --now)          NOW="${2-}";          shift 2 ;;
    --dry-run)      DRY_RUN=1;            shift ;;
    -h|--help) echo "Usage: toolchain-advisor.sh --handoff <json> [--requirements <json>] [--scaffold-dir <dir>] [--out <path>] [--dry-run]" >&2; exit 0 ;;
    *) echo "toolchain-advisor: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$HANDOFF" ]; then echo "toolchain-advisor: --handoff <json> is required" >&2; exit 2; fi
if [ ! -f "$HANDOFF" ]; then echo "toolchain-advisor: handoff not found: $HANDOFF" >&2; exit 2; fi
if [ -z "$OUT" ]; then OUT="standards/toolchain.json"; fi
if [ -z "$NOW" ]; then NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ); fi

HANDOFF="$HANDOFF" REQ="$REQ" SCAFFOLD_DIR="$SCAFFOLD_DIR" OUT="$OUT" NOW="$NOW" DRY_RUN="$DRY_RUN" ruby -rjson -e '
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
  handoff=ENV["HANDOFF"]; req=ENV["REQ"]; sdir=ENV["SCAFFOLD_DIR"]
  out=ENV["OUT"]; now=ENV["NOW"]; dry=ENV["DRY_RUN"]=="1"

  h = JSON.parse(File.read(handoff))
  platform = h["platform"] || "aws"
  iac_tool = (h["iac_targets"] || ["terraform"]).first || "terraform"

  reqs = (!req.empty? && File.exist?(req)) ? JSON.parse(File.read(req)) : nil
  pillars = (reqs && reqs["pillars"]) || {}
  has_integration = !(pillars["integration"] || []).empty?
  has_data        = !(pillars["data"] || []).empty?

  # Platform-native tool picks.
  NATIVE_MSG = {"aws"=>"amazon-sqs-sns","azure"=>"azure-service-bus","gcp"=>"google-pubsub"}
  NATIVE_K8S = {"aws"=>"amazon-eks","azure"=>"azure-aks","gcp"=>"google-gke"}

  recs = []  # {category, tool, platform_native, rationale, source_id, grounding}
  add = lambda do |category, tool, native, rationale, src|
    recs << {"category"=>category, "tool"=>tool, "platform_native"=>native,
             "rationale"=>rationale, "source_id"=>src,
             "grounding"=> (src ? "grounded" : "needs_grounding")}
  end

  # Always-on toolchain.
  add.call("iac", iac_tool, true, "provision infrastructure for #{platform}", "terraform-recommended-practices")
  add.call("observability", "opentelemetry", false, "instrument traces/metrics/logs", "opentelemetry-docs")
  add.call("gitops", "argocd", false, "declarative continuous delivery", "argocd-gitops")
  add.call("finops", "finops-practices", false, "tagging, budgets, anomaly detection", "finops-framework")
  add.call("containers", NATIVE_K8S[platform], true, "container orchestration", nil)
  add.call("ci-cd", "github-actions", false, "build/test/deploy pipeline", nil)
  add.call("policy-as-code", "opa-conftest", false, "enforce policy before deploy", nil)
  add.call("testing", "terratest", false, "infrastructure test harness", nil)

  # Conditional toolchain from the requirements.
  add.call("messaging", NATIVE_MSG[platform], true, "event-driven communication", "enterprise-integration-patterns") if has_integration
  add.call("db-migrations", "flyway", false, "versioned schema migrations", nil) if has_data

  # S-48: survey all viable alternatives per category (native + portable) so the
  # developer can consider the whole field, not just the primary pick.
  # Each entry: [tool, portable, native_platform_or_nil, source_id_or_nil].
  ALT = {
    "iac" => [["terraform",true,nil,"terraform-recommended-practices"],["aws-cloudformation",false,"aws","aws-cloudformation-best-practices"],["azure-bicep",false,"azure","azure-bicep-best-practices"],["pulumi",true,nil,nil],["crossplane",true,nil,nil]],
    "observability" => [["opentelemetry",true,nil,"opentelemetry-docs"],["prometheus-grafana",true,nil,nil],["datadog",true,nil,nil],["amazon-cloudwatch",false,"aws",nil],["azure-monitor",false,"azure",nil],["google-cloud-operations",false,"gcp",nil]],
    "gitops" => [["argocd",true,nil,"argocd-gitops"],["flux",true,nil,nil]],
    "finops" => [["finops-practices",true,nil,"finops-framework"],["kubecost",true,nil,nil]],
    "containers" => [["kubernetes",true,nil,nil],["amazon-eks",false,"aws",nil],["azure-aks",false,"azure",nil],["google-gke",false,"gcp",nil]],
    "ci-cd" => [["github-actions",true,nil,nil],["gitlab-ci",true,nil,nil],["aws-codepipeline",false,"aws",nil],["azure-devops",false,"azure",nil],["google-cloud-build",false,"gcp",nil]],
    "policy-as-code" => [["opa-conftest",true,nil,nil],["checkov",true,nil,nil],["aws-config",false,"aws",nil],["azure-policy",false,"azure",nil],["gcp-policy-controller",false,"gcp",nil]],
    "testing" => [["terratest",true,nil,nil],["pact",true,nil,nil]],
    "messaging" => [["apache-kafka",true,nil,"enterprise-integration-patterns"],["rabbitmq",true,nil,"enterprise-integration-patterns"],["amazon-sqs-sns",false,"aws","enterprise-integration-patterns"],["azure-service-bus",false,"azure","enterprise-integration-patterns"],["google-pubsub",false,"gcp","enterprise-integration-patterns"]],
    "db-migrations" => [["flyway",true,nil,nil],["liquibase",true,nil,nil],["alembic",true,nil,nil]]
  }
  # S-49: a plain business-language explanation for each tool (what it means for
  # you and the trade-off), so a non-technical founder can choose.
  PLAIN = {
    "terraform"=>"describe your infrastructure as code that works across clouds; the widely used default",
    "aws-cloudformation"=>"AWS-built infrastructure-as-code; deep AWS fit but ties you to AWS",
    "azure-bicep"=>"Azure-built infrastructure-as-code; clean and native to Azure",
    "pulumi"=>"infrastructure as code using real programming languages; handy when the logic is complex",
    "crossplane"=>"manage infrastructure the Kubernetes way; good if you already run Kubernetes",
    "opentelemetry"=>"a vendor-neutral way to watch the health of your system, so you are not locked to one monitoring vendor",
    "prometheus-grafana"=>"popular open-source monitoring and dashboards you run yourself; powerful, more to operate",
    "datadog"=>"an all-in-one paid monitoring service; little setup but an ongoing subscription cost",
    "amazon-cloudwatch"=>"the AWS built-in monitoring; works out of the box on AWS, keeps you on AWS",
    "azure-monitor"=>"the Azure built-in monitoring; native to Azure",
    "google-cloud-operations"=>"the Google Cloud built-in monitoring; native to Google Cloud",
    "argocd"=>"keeps what is running in sync with what is in your code repository, so releases are automatic and auditable",
    "flux"=>"a lightweight tool that deploys automatically from your code repository",
    "finops-practices"=>"habits that keep cloud spending visible and under control",
    "kubecost"=>"shows what the Kubernetes workloads actually cost so you can trim waste",
    "kubernetes"=>"the standard way to run containers at scale on any cloud; powerful but more to learn",
    "amazon-eks"=>"managed Kubernetes on AWS; the provider runs the hard parts, native to AWS",
    "azure-aks"=>"managed Kubernetes on Azure; native to Azure",
    "google-gke"=>"managed Kubernetes on Google Cloud; native to Google Cloud",
    "github-actions"=>"automatically builds, tests, and ships your code from your repository",
    "gitlab-ci"=>"build-test-ship automation built into GitLab",
    "aws-codepipeline"=>"the AWS release pipeline; native to AWS",
    "azure-devops"=>"the Microsoft release pipeline; native to Azure",
    "google-cloud-build"=>"the Google Cloud build and release service; native to Google Cloud",
    "opa-conftest"=>"automatically checks your setup against your rules before it ships",
    "checkov"=>"scans your infrastructure code for risky settings before deploy",
    "aws-config"=>"the AWS built-in compliance and guardrail checks",
    "azure-policy"=>"the Azure built-in compliance and guardrail checks",
    "gcp-policy-controller"=>"the Google Cloud built-in policy guardrails",
    "terratest"=>"automated tests that prove your infrastructure actually works",
    "pact"=>"tests that the services talking to each other keep their promises",
    "apache-kafka"=>"a high-volume event backbone for large-scale streaming; powerful, more to run",
    "rabbitmq"=>"a reliable message queue that is simpler to start with",
    "amazon-sqs-sns"=>"the AWS managed queues and notifications; almost nothing to operate, native to AWS",
    "azure-service-bus"=>"the Azure managed enterprise messaging; native to Azure",
    "google-pubsub"=>"the Google Cloud managed global messaging; native to Google Cloud",
    "flyway"=>"safely version and apply database changes",
    "liquibase"=>"track and apply database changes in a controlled way",
    "alembic"=>"version database changes for Python projects"
  }
  recs.each do |r|
    r["alternatives"] = (ALT[r["category"]] || []).map do |tool, portable, native, src|
      {"tool"=>tool, "platform_native"=>(native == platform), "portable"=>portable,
       "source_id"=>src, "grounding"=> (src ? "grounded" : "needs_grounding"),
       "plain"=> (PLAIN[tool] || "an option for #{r["category"]}; ask for details")}
    end
  end

  grounded_n = recs.count { |r| r["grounding"] == "grounded" }
  needs = recs.select { |r| r["grounding"] == "needs_grounding" }.map { |r| r["category"] }

  # Deterministic scaffolds (original starter skeletons) for stable-shape tools.
  scaffolds = []
  if !sdir.empty? && !dry
    require "fileutils"
    FileUtils.mkdir_p(sdir)
    argocd = +"apiVersion: argoproj.io/v1alpha1\nkind: Application\nmetadata:\n  name: app\nspec:\n  project: default\n  source:\n    repoURL: REPLACE_ME\n    path: deploy\n  destination:\n    server: https://kubernetes.default.svc\n    namespace: default\n"
    File.write(File.join(sdir, "argocd-application.yaml"), argocd); scaffolds << "argocd-application.yaml"
    opa = +"package deploy.guard\n\ndeny[msg] {\n  not input.encryption_at_rest\n  msg := \"encryption at rest is required\"\n}\n"
    File.write(File.join(sdir, "policy.rego"), opa); scaffolds << "policy.rego"
    ci = +"name: ci\non: [push]\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: echo build-test-deploy\n"
    File.write(File.join(sdir, "ci.yaml"), ci); scaffolds << "ci.yaml"
    if has_data
      File.write(File.join(sdir, "V1__init.sql"), "-- versioned migration; edit before applying\nCREATE TABLE IF NOT EXISTS example (id INT PRIMARY KEY);\n"); scaffolds << "V1__init.sql"
    end
  end

  doc = {
    "schema_version" => "1.0",
    "generated_at"   => now,
    "platform"       => platform,
    "recommendations"=> recs,
    "needs_grounding"=> needs,
    "scaffolds"      => scaffolds
  }

  unless dry
    require "fileutils"
    d = File.dirname(out); FileUtils.mkdir_p(d) unless d.empty? || d == "."
    File.write(out, JSON.pretty_generate(doc) + "\n")
  end

  STDERR.puts "dry_run=true" if dry
  STDERR.puts "toolchain=#{out}"
  STDERR.puts "platform=#{platform}"
  STDERR.puts "recommendations=#{recs.length}"
  STDERR.puts "grounded=#{grounded_n}"
  STDERR.puts "needs_grounding=#{needs.length}"
  STDERR.puts "scaffolds=#{scaffolds.length}"
'
exit $?
