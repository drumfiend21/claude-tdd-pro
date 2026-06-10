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
