#!/usr/bin/env bash
# compliance/aibom.sh — C-7 AI Bill of Materials emitter per §16:
# "AIBOM compliance/aibom.sh emits compliance/AIBOM-<tag>.json in
# CycloneDX 1.6 + AI/ML extension."
#
# Usage:
#   aibom.sh --tag <semver> --emit <path>
#            [--include-models <csv>] [--include-fine-tunes]
#            [--include-prompts] [--force]
#   aibom.sh --validate <path>

set -uo pipefail

TAG=""
EMIT=""
INCLUDE_MODELS=""
INCLUDE_FINE_TUNES=0
INCLUDE_PROMPTS=0
FORCE=0
VALIDATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --include-models) INCLUDE_MODELS="$2"; shift 2 ;;
    --include-fine-tunes) INCLUDE_FINE_TUNES=1; shift ;;
    --include-prompts) INCLUDE_PROMPTS=1; shift ;;
    --force) FORCE=1; shift ;;
    --validate) VALIDATE="$2"; shift 2 ;;
    *) echo "aibom: unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$VALIDATE" ]]; then
  [[ ! -f "$VALIDATE" ]] && { echo "aibom: validate target not found: $VALIDATE" >&2; exit 2; }
  VALIDATE="$VALIDATE" node -e '
    const j = JSON.parse(require("fs").readFileSync(process.env.VALIDATE, "utf8"));
    if (j.bomFormat !== "CycloneDX") { process.stderr.write("aibom: invalid bomFormat\n"); process.exit(2); }
    if (j.specVersion !== "1.6") { process.stderr.write("aibom: specVersion must be 1.6\n"); process.exit(2); }
    if (!Array.isArray(j.components)) { process.stderr.write("aibom: components array required\n"); process.exit(2); }
    if (!j.metadata || !j.metadata.timestamp) { process.stderr.write("aibom: metadata.timestamp required\n"); process.exit(2); }
    process.stderr.write("aibom: valid CycloneDX 1.6\n");
  '
  exit $?
fi

[[ -z "$TAG" || -z "$EMIT" ]] && { echo "aibom: --tag and --emit required" >&2; exit 2; }
if ! [[ "$TAG" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "aibom: --tag \"$TAG\" not semver (expected vX.Y.Z); tag must be semver" >&2
  exit 2
fi
if [[ -f "$EMIT" && "$FORCE" -eq 0 ]]; then
  echo "aibom: $EMIT exists; pass --force to overwrite" >&2
  exit 2
fi
mkdir -p "$(dirname "$EMIT")"

TAG="$TAG" EMIT="$EMIT" INCLUDE_MODELS="$INCLUDE_MODELS" \
INCLUDE_FINE_TUNES="$INCLUDE_FINE_TUNES" INCLUDE_PROMPTS="$INCLUDE_PROMPTS" node -e '
  const fs = require("fs");
  const crypto = require("crypto");
  const tag = process.env.TAG;
  const components = [];

  // Model pins from lock.json.
  const lockPath = ".claude-tdd-pro/lock.json";
  if (fs.existsSync(lockPath)) {
    try {
      const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
      const pins = lock.model_pins || {};
      for (const role of Object.keys(pins).sort()) {
        components.push({
          type: "machine-learning-model",
          name: pins[role],
          version: "pinned",
          modelCard: { role, classification: "pinned-via-lock-json" }
        });
      }
    } catch {}
  }

  // Explicit --include-models.
  if (process.env.INCLUDE_MODELS) {
    for (const m of process.env.INCLUDE_MODELS.split(",").filter(Boolean)) {
      components.push({
        type: "machine-learning-model",
        name: m,
        modelCard: { role: "configured", classification: "external-api" }
      });
    }
  }

  // Fine-tunes from prompts/fine-tunes.yaml.
  if (process.env.INCLUDE_FINE_TUNES === "1" && fs.existsSync("prompts/fine-tunes.yaml")) {
    const c = fs.readFileSync("prompts/fine-tunes.yaml", "utf8");
    const blocks = c.split(/^- /m).slice(1);
    for (const blk of blocks) {
      const id = (blk.match(/id:\s*(\S+)/) || [])[1];
      const base = (blk.match(/base_model:\s*(\S+)/) || [])[1];
      const uri = (blk.match(/artifact_uri:\s*(\S+)/) || [])[1];
      const hash = (blk.match(/hash:\s*(\S+)/) || [])[1];
      if (id) components.push({
        type: "machine-learning-model",
        name: id,
        modelCard: { base_model: base, artifact_uri: uri, hash, classification: "fine-tune" }
      });
    }
  }

  // Prompt versions from prompts/registry.yaml.
  if (process.env.INCLUDE_PROMPTS === "1" && fs.existsSync("prompts/registry.yaml")) {
    const c = fs.readFileSync("prompts/registry.yaml", "utf8");
    const blocks = c.split(/^- /m).slice(1);
    for (const blk of blocks) {
      const id = (blk.match(/id:\s*(\S+)/) || [])[1];
      const versionMatches = [...blk.matchAll(/version:\s*(\S+)/g)];
      for (const vm of versionMatches) {
        components.push({
          type: "data",
          name: id,
          version: vm[1],
          modelCard: { classification: "prompt" }
        });
      }
    }
  }

  // Stable sha256 over the component list for downstream verification.
  const componentsHash = "sha256:" + crypto.createHash("sha256")
    .update(JSON.stringify(components)).digest("hex");

  const aibom = {
    bomFormat: "CycloneDX",
    specVersion: "1.6",
    serialNumber: "urn:uuid:claude-tdd-pro-" + tag,
    version: 1,
    metadata: {
      timestamp: new Date().toISOString(),
      tools: [{ name: "claude-tdd-pro/aibom.sh", version: tag }],
      supplier: { name: "claude-tdd-pro", url: ["https://github.com/anthropics/claude-tdd-pro"] }
    },
    components,
    properties: [{ name: "components_hash", value: componentsHash }]
  };
  // Compact JSON so spec greps that expect no whitespace match.
  fs.writeFileSync(process.env.EMIT, JSON.stringify(aibom));
'
