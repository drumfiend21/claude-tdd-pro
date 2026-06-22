#!/usr/bin/env bash
# vendor/canonical-vocabulary/refresh-vocabulary.sh - materialize / refresh the 4-axis
# canonical vocabulary mirrors (ADR-0008, §28.28 Wave 1).
#
# The composite engine binds rules to tools via four INDUSTRY-STANDARD authorities rather
# than CTP-invented strings. This script writes read-only mirrors of those authorities into
# vendor/canonical-vocabulary/ and records provenance + license. ALL FOUR SOURCES ARE
# PERMISSIVELY LICENSED (MIT / Apache-2.0) — free to use, distribute, and use commercially:
#
#   linguist-languages.json  GitHub Linguist languages.yml          MIT        (live-fetched)
#   purl-types.json          package-url/purl-spec PURL types        MIT        (curated list)
#   k8s-gvks.json            Kubernetes built-in Group/Version/Kind  Apache-2.0 (curated list)
#   iac-dialects.json        Checkov/Trivy/Kubescape dialect union   Apache-2.0 (curated list)
#
# Network-tolerant: a failed Linguist fetch keeps the existing mirror (never blocks / empties).
# Idempotent: re-running yields byte-identical output for the curated axes; the Linguist axis
# tracks upstream. Wired into the §28.22/§28.23 daily refresh.
#
# CLI: [--dir <vendor-dir>] [--offline]   exit 0 ok / 2 usage.

set -uo pipefail
DIR=""; OFFLINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2-}"; shift 2 ;;
    --offline) OFFLINE=1; shift ;;
    -h|--help) echo "Usage: refresh-vocabulary.sh [--dir <vendor-dir>] [--offline]" >&2; exit 0 ;;
    *) echo "refresh-vocabulary: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$DIR" ] && DIR="$(cd "$(dirname "$0")" && pwd -P)"
mkdir -p "$DIR"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- axis 1: GitHub Linguist languages (MIT) — live-fetched, transformed to a compact map ----
LINGUIST_URL="https://raw.githubusercontent.com/github-linguist/linguist/main/lib/linguist/languages.yml"
LING_RAW="$(mktemp)"; LING_OK=0
if [ "$OFFLINE" -eq 0 ] && command -v curl >/dev/null 2>&1; then
  if curl -fsSL --max-time 20 "$LINGUIST_URL" -o "$LING_RAW" 2>/dev/null && [ -s "$LING_RAW" ]; then
    LING_OK=1
  fi
fi
if [ "$LING_OK" -eq 1 ]; then
  RAW="$LING_RAW" OUT="$DIR/linguist-languages.json" ruby -ryaml -rjson -rdigest -e '
    d = YAML.unsafe_load_file(ENV["RAW"]) rescue {}
    langs = {}; ext_index = {}
    (d || {}).each do |name, meta|
      next unless meta.is_a?(Hash)
      aliases = (meta["aliases"] || []) + [name.downcase.tr(" ", "-")]
      exts = (meta["extensions"] || [])
      langs[name] = { "type" => meta["type"], "aliases" => aliases.uniq, "extensions" => exts }
      exts.each { |e| (ext_index[e.downcase] ||= []) << name }
    end
    out = { "_authority" => "GitHub Linguist", "_license" => "MIT",
            "_source" => "github-linguist/linguist:lib/linguist/languages.yml",
            "_count" => langs.size, "languages" => langs, "by_extension" => ext_index }
    File.write(ENV["OUT"], JSON.pretty_generate(out) + "\n")
    STDERR.puts "refresh-vocabulary: linguist languages=#{langs.size} (live)"
  '
else
  STDERR.puts "refresh-vocabulary: linguist fetch unavailable; keeping existing mirror"
  [ -f "$DIR/linguist-languages.json" ] || echo '{"_authority":"GitHub Linguist","_license":"MIT","_count":0,"languages":{},"by_extension":{}}' > "$DIR/linguist-languages.json"
fi
rm -f "$LING_RAW"

# ---- axes 2-4: curated enumerations (source-of-truth embedded; provenance permissive) ----
DIR="$DIR" NOW="$NOW" ruby -rjson -e '
  dir = ENV["DIR"]; now = ENV["NOW"]

  # axis 2: PURL types — package-url/purl-spec (MIT). Stable, small enumeration.
  purl_types = %w[
    alpm apk bitbucket bitnami cargo cocoapods composer conan conda cpan cran deb docker
    gem generic github golang hackage hex huggingface luarocks maven mlflow npm nuget oci
    pub pypi qpkg rpm swid swift
  ]
  File.write(File.join(dir, "purl-types.json"), JSON.pretty_generate(
    { "_authority" => "package-url / purl-spec", "_license" => "MIT",
      "_source" => "package-url/purl-spec:PURL-TYPES.rst", "_count" => purl_types.size,
      "types" => purl_types }) + "\n")

  # axis 3: Kubernetes built-in Group/Version/Kind (Apache-2.0). Stable built-in API surface.
  k8s_gvks = [
    "v1/Pod","v1/Service","v1/ConfigMap","v1/Secret","v1/ServiceAccount","v1/Namespace",
    "v1/PersistentVolume","v1/PersistentVolumeClaim","v1/Node","v1/Endpoints","v1/Event",
    "apps/v1/Deployment","apps/v1/StatefulSet","apps/v1/DaemonSet","apps/v1/ReplicaSet",
    "batch/v1/Job","batch/v1/CronJob",
    "networking.k8s.io/v1/Ingress","networking.k8s.io/v1/NetworkPolicy",
    "rbac.authorization.k8s.io/v1/Role","rbac.authorization.k8s.io/v1/RoleBinding",
    "rbac.authorization.k8s.io/v1/ClusterRole","rbac.authorization.k8s.io/v1/ClusterRoleBinding",
    "policy/v1/PodDisruptionBudget","autoscaling/v2/HorizontalPodAutoscaler",
    "storage.k8s.io/v1/StorageClass","admissionregistration.k8s.io/v1/ValidatingWebhookConfiguration",
    "apiextensions.k8s.io/v1/CustomResourceDefinition","gateway.networking.k8s.io/v1/Gateway",
    "gateway.networking.k8s.io/v1/HTTPRoute"
  ]
  File.write(File.join(dir, "k8s-gvks.json"), JSON.pretty_generate(
    { "_authority" => "Kubernetes API", "_license" => "Apache-2.0",
      "_source" => "kubernetes/kubernetes (built-in GVKs)", "_count" => k8s_gvks.size,
      "gvks" => k8s_gvks }) + "\n")

  # axis 4: IaC dialect consensus — union of Checkov / Trivy / Kubescape supported frameworks
  # (all Apache-2.0). Maps a dialect to the file globs/markers that identify it.
  iac_dialects = {
    "terraform"          => { "extensions" => [".tf", ".tf.json"] },
    "terraform_plan"     => { "extensions" => [".json"], "markers" => ["planned_values"] },
    "cloudformation"     => { "extensions" => [".template", ".cfn.yaml", ".cfn.json"], "markers" => ["AWSTemplateFormatVersion"] },
    "kubernetes"         => { "extensions" => [".yaml", ".yml"], "markers" => ["apiVersion", "kind"] },
    "helm"               => { "extensions" => [".yaml", ".tpl"], "markers" => ["Chart.yaml"] },
    "kustomize"          => { "filenames" => ["kustomization.yaml", "kustomization.yml"] },
    "dockerfile"         => { "filenames" => ["Dockerfile"], "extensions" => [".dockerfile"] },
    "github_actions"     => { "globs" => [".github/workflows/*.yml", ".github/workflows/*.yaml"] },
    "gitlab_ci"          => { "filenames" => [".gitlab-ci.yml"] },
    "azure_pipelines"    => { "filenames" => ["azure-pipelines.yml", "azure-pipelines.yaml"] },
    "circleci"           => { "globs" => [".circleci/config.yml"] },
    "bitbucket_pipelines"=> { "filenames" => ["bitbucket-pipelines.yml"] },
    "ansible"            => { "extensions" => [".yml", ".yaml"], "markers" => ["hosts:", "tasks:"] },
    "serverless"         => { "filenames" => ["serverless.yml", "serverless.yaml"] },
    "arm"                => { "extensions" => [".json"], "markers" => ["$schema", "resources"] },
    "bicep"              => { "extensions" => [".bicep"] },
    "openapi"            => { "filenames" => ["openapi.yaml", "openapi.json", "swagger.yaml", "swagger.json"] },
    "cdk"                => { "markers" => ["aws-cdk-lib"] }
  }
  File.write(File.join(dir, "iac-dialects.json"), JSON.pretty_generate(
    { "_authority" => "Checkov / Trivy / Kubescape (dialect consensus)", "_license" => "Apache-2.0",
      "_source" => "bridgecrewio/checkov + aquasecurity/trivy + kubescape/kubescape",
      "_count" => iac_dialects.size, "dialects" => iac_dialects }) + "\n")

  # provenance ledger (per mirror: authority, url, license, fetched_at, content_hash)
  require "digest"
  prov = {}
  { "linguist-languages.json" => ["GitHub Linguist", "https://github.com/github-linguist/linguist", "MIT"],
    "purl-types.json"         => ["package-url/purl-spec", "https://github.com/package-url/purl-spec", "MIT"],
    "k8s-gvks.json"           => ["Kubernetes", "https://github.com/kubernetes/kubernetes", "Apache-2.0"],
    "iac-dialects.json"       => ["Checkov/Trivy/Kubescape", "https://www.checkov.io/", "Apache-2.0"]
  }.each do |f, (auth, url, lic)|
    p = File.join(dir, f); next unless File.exist?(p)
    prov[f] = { "authority" => auth, "url" => url, "license" => lic,
                "fetched_at" => now, "content_hash" => "sha256:" + Digest::SHA256.hexdigest(File.read(p)) }
  end
  File.write(File.join(dir, "provenance.json"), JSON.pretty_generate(
    { "refreshed_at" => now,
      "license_posture" => "all mirrors permissively licensed (MIT/Apache-2.0); free to use, distribute, and use commercially",
      "mirrors" => prov }) + "\n")
  STDERR.puts "refresh-vocabulary: purl=#{purl_types.size} k8s_gvk=#{k8s_gvks.size} iac_dialects=#{iac_dialects.size}; provenance written"
'
