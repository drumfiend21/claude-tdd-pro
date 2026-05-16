#!/usr/bin/env bash
# /pr-source-add — G-9 auto-scaffold for PR-SOURCES.yaml entry.
# Per §16 G-9: namespace by source_class:
#   federal-financial-regulator → us-government/
#   financial-industry          → finance-industry/
#   gold-standard-process       → linux-foundation/
set -uo pipefail

GITHUB=""; ID=""; SOURCE_CLASS=""; TREE=""; DRY_RUN=0; REGISTRY=""; STUB=""; ARG=""
TIER=""; ACTIVITY_WINDOW="365d"; NOW=""; NON_INTERACTIVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --github) GITHUB="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --source-class) SOURCE_CLASS="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --gh-clone-stub) STUB="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    --activity-window) ACTIVITY_WINDOW="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) echo "Usage: pr-source-add.sh [G-9: --github <gh> --id <id> --source-class <c> --tree <dir>] | [L-17/L-20: <org/repo> --registry <yaml> [--gh-clone-stub <dir>] [--tier N] [--source-class C] [--activity-window 365d] [--now <iso>]] [--dry-run] [--non-interactive]"; exit 0 ;;
    *) [[ -z "$ARG" ]] && ARG="$1"; shift ;;
  esac
done

# L-20 mode: positional <org/repo> [--registry <yaml> [--gh-clone-stub <dir>]] [--tier N] [...].
# Triggered by positional ARG with org/repo or by --registry.
if [[ -n "$ARG" || -n "$REGISTRY" ]]; then
  [[ -z "$ARG" ]] && { echo "pr-source-add: <org/repo> required in registry mode" >&2; exit 2; }
  # Format check.
  if [[ ! "$ARG" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "pr-source-add: invalid_format $ARG (expected: <org>/<repo>)" >&2
    exit 2
  fi
  ORG="${ARG%/*}"
  REPO="${ARG#*/}"
  NEW_ID="$REPO"

  # Tier requirement (--non-interactive without --tier blocks).
  if [[ -z "$TIER" && "$NON_INTERACTIVE" -eq 1 ]]; then
    echo "pr-source-add: tier_required (run with --tier <int> in --non-interactive mode; interactive prompt suppressed)" >&2
    exit 2
  fi

  # Repo activity check (only when stub provides metadata).
  if [[ -n "$STUB" ]]; then
    META="$STUB/$ORG/$REPO/repo-metadata.json"
    if [[ -f "$META" ]]; then
      [[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      case "$ACTIVITY_WINDOW" in
        *d) WIN_SEC=$((${ACTIVITY_WINDOW%d} * 86400)) ;;
        *h) WIN_SEC=$((${ACTIVITY_WINDOW%h} * 3600)) ;;
        *) WIN_SEC=31536000 ;;
      esac
      DIFF_SEC=$(META="$META" NOW="$NOW" node -e '
        const fs = require("fs");
        const j = JSON.parse(fs.readFileSync(process.env.META, "utf8"));
        const pushed = j.pushed_at;
        if (!pushed) { process.stdout.write("0"); process.exit(0); }
        process.stdout.write(String(Math.floor((new Date(process.env.NOW) - new Date(pushed))/1000)));
      ')
      if [[ "$DIFF_SEC" -gt "$WIN_SEC" ]]; then
        echo "pr-source-add: inactive_repo $ARG window=$ACTIVITY_WINDOW (last pushed_at exceeds activity window; reject by default)" >&2
        exit 2
      fi
      LANG_DETECTED=$(META="$META" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.META,"utf8"));process.stdout.write(j.language||"")')
      echo "pr-source-add: metadata_extracted=true repo=$ARG language=$LANG_DETECTED pushed_at=$(META="$META" node -e "const j=JSON.parse(require(\"fs\").readFileSync(process.env.META,\"utf8\"));process.stdout.write(j.pushed_at||\"\")")" >&2
      # Fetcher template selection.
      case "$LANG_DETECTED" in
        JavaScript|TypeScript) FETCHER="node-default" ;;
        Python) FETCHER="python-default" ;;
        Ruby) FETCHER="ruby-default" ;;
        *) FETCHER="generic-default" ;;
      esac
      echo "pr-source-add: fetcher_template=$FETCHER source_class=${SOURCE_CLASS:-unspecified}" >&2
    fi
  fi

  # Duplicate check.
  if [[ -n "$REGISTRY" && -f "$REGISTRY" ]]; then
    if grep -qE "id:[[:space:]]*${NEW_ID}[[:space:]]*[,}]?" "$REGISTRY"; then
      echo "pr-source-add: duplicate_id=$NEW_ID (already present in registry $REGISTRY)" >&2
      exit 2
    fi
  fi

  # Namespace routing emission per source_class.
  if [[ -n "$SOURCE_CLASS" ]]; then
    case "$SOURCE_CLASS" in
      federal-financial-regulator) ROUTE_NS="us-government" ;;
      financial-industry) ROUTE_NS="finance-industry" ;;
      gold-standard-process) ROUTE_NS="linux-foundation" ;;
      *) ROUTE_NS="industry-self-regulatory" ;;
    esac
    echo "pr-source-add: namespace=$ROUTE_NS source_class=$SOURCE_CLASS" >&2
  fi

  # Dry-run path.
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "pr-source-add: planned: add $ARG (id=$NEW_ID tier=${TIER:-?} source_class=${SOURCE_CLASS:-?} dry_run=true; no registry write)" >&2
    exit 0
  fi

  # Registry write.
  [[ -z "$REGISTRY" ]] && { echo "pr-source-add: --registry <yaml> required for registry mode" >&2; exit 2; }
  [[ ! -f "$REGISTRY" ]] && { echo "pr-source-add: registry $REGISTRY not found" >&2; exit 2; }
  REG="$REGISTRY" NEW_ID="$NEW_ID" ARG="$ARG" TIER="$TIER" SC="$SOURCE_CLASS" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  data = YAML.load_file(ENV["REG"]) rescue {}
  data["operator_namespace"] ||= []
  entry = { "id" => ENV["NEW_ID"], "repo" => ENV["ARG"] }
  entry["tier"] = ENV["TIER"].to_i if ENV["TIER"] && !ENV["TIER"].empty?
  entry["source_class"] = ENV["SC"] if ENV["SC"] && !ENV["SC"].empty?
  data["operator_namespace"] << entry
  File.write(ENV["REG"], YAML.dump(data))
  STDERR.puts "pr-source-add: added id=#{ENV["NEW_ID"]} repo=#{ENV["ARG"]} tier=#{ENV["TIER"]} source_class=#{ENV["SC"]} to operator_namespace"
  '
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "pr-source-add: dry-run; would add id=$ID github=$GITHUB class=$SOURCE_CLASS (no writes)" >&2
  exit 0
fi

[[ -z "$GITHUB" || -z "$ID" || -z "$SOURCE_CLASS" || -z "$TREE" ]] && {
  echo "pr-source-add: --github, --id, --source-class, --tree required" >&2; exit 2; }

case "$SOURCE_CLASS" in
  federal-financial-regulator) NS="us-government" ;;
  financial-industry) NS="finance-industry" ;;
  gold-standard-process) NS="linux-foundation" ;;
  *) NS="industry-self-regulatory" ;;
esac
mkdir -p "$TREE/$NS"
TARGET="$TREE/$NS/$ID.yaml"
[[ -f "$TARGET" ]] && { echo "pr-source-add: id $ID collision at $TARGET" >&2; exit 2; }
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
URL="https://github.com/$GITHUB"
cat > "$TARGET" <<YAML
source:
  id: $ID
  authoritative_publisher: "github.com/$GITHUB"
  authoritative_url: "$URL"
  registry_link: PR-SOURCES.yaml
  fetched_at: "$TS"
  content_hash: "sha256:pending-first-fetch"
  fetch_frequency: daily
  fragility_tier: medium
  license_note: "see-repo"
  source_class: "$SOURCE_CLASS"
rules: []
recommended_set: []
all_set: []
YAML
echo "pr-source-add: created $TARGET (class=$SOURCE_CLASS)" >&2
