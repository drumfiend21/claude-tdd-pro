#!/usr/bin/env bash
# /pr-source-remove — G-9 archive for PR-SOURCES.yaml entry.
set -uo pipefail

ID=""; TREE=""; REGISTRY=""; FORCE=0; ARG=""; DRY_RUN=0
EVIDENCE_DIR=""; NOW=""; AUDIT_LOG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --tree) TREE="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    -h|--help) echo "Usage: pr-source-remove.sh [--id <id> --tree <dir>] | [<id> --registry <yaml> [--evidence-dir <dir>] [--force] [--audit-log <jsonl>] [--now <iso>]] [--dry-run]"; exit 0 ;;
    *) [[ -z "$ARG" ]] && ARG="$1"; shift ;;
  esac
done

# L-17/L-21 registry mode: positional <id> + --registry <yaml>.
if [[ -n "$REGISTRY" || -n "$ARG" ]]; then
  RM_ID="${ID:-$ARG}"
  [[ -z "$RM_ID" ]] && { echo "pr-source-remove: <id> required in registry mode" >&2; exit 2; }
  [[ -z "$REGISTRY" ]] && { echo "pr-source-remove: --registry <yaml> required in registry mode" >&2; exit 2; }
  [[ ! -f "$REGISTRY" ]] && { echo "pr-source-remove: registry $REGISTRY not found" >&2; exit 2; }
  [[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Unknown id check.
  if ! grep -qE "id:[[:space:]]*${RM_ID}[[:space:]]*[,}]?" "$REGISTRY"; then
    echo "pr-source-remove: unknown_source_id $RM_ID (try /pr-source-list to see registered sources)" >&2
    exit 2
  fi

  # Sole-evidence check (only when evidence dir present).
  if [[ -n "$EVIDENCE_DIR" && -d "$EVIDENCE_DIR" ]]; then
    SOLE_RULES=$(EV="$EVIDENCE_DIR" SRC="$RM_ID" node -e '
      const fs = require("fs");
      const path = require("path");
      const out = [];
      for (const f of fs.readdirSync(process.env.EV)) {
        if (!f.endsWith(".yaml")) continue;
        const p = path.join(process.env.EV, f);
        let body;
        try { body = fs.readFileSync(p, "utf8"); } catch { continue; }
        if (!body.includes(`source_id: ${process.env.SRC}`)) continue;
        if (!body.includes("sole_evidence: true")) continue;
        const m = body.match(/rule_id:\s*(\S+)/);
        if (m) out.push(m[1]);
      }
      process.stdout.write(out.join(" "));
    ')
    if [[ -n "$SOLE_RULES" && "$FORCE" -ne 1 ]]; then
      echo "pr-source-remove: sole_evidence rules depend on $RM_ID; cannot remove without --force" >&2
      for r in $SOLE_RULES; do echo "pr-source-remove: rule=$r (sole_evidence=true source=$RM_ID)" >&2; done
      exit 2
    fi
    if [[ "$FORCE" -eq 1 && -n "$SOLE_RULES" ]]; then
      # Mark each affected rule's provenance_status.
      for r in $SOLE_RULES; do
        for f in "$EVIDENCE_DIR"/*.yaml; do
          [[ ! -f "$f" ]] && continue
          if grep -q "rule_id: $r" "$f" && grep -q "source_id: $RM_ID" "$f"; then
            echo "provenance_status: source-removed" >> "$f"
          fi
        done
      done
    fi
  fi

  # Dry-run path: report planned operations, no writes.
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "pr-source-remove: planned: archive $RM_ID (no files moved; dry_run=true)" >&2
    exit 0
  fi

  # Archive evidence yaml if present.
  TS_SAFE=$(echo "$NOW" | tr ':' '-')
  if [[ -n "$EVIDENCE_DIR" && -f "$EVIDENCE_DIR/$RM_ID.yaml" ]]; then
    mkdir -p "$EVIDENCE_DIR/_archived"
    ARCHIVE="$EVIDENCE_DIR/_archived/$RM_ID-$TS_SAFE.yaml"
    {
      echo "removed_at: $NOW"
      echo "removed_id: $RM_ID"
      cat "$EVIDENCE_DIR/$RM_ID.yaml"
    } > "$ARCHIVE"
    rm -f "$EVIDENCE_DIR/$RM_ID.yaml"
    echo "pr-source-remove: archived to $ARCHIVE" >&2
  fi

  # Force-mode audit-log entry.
  if [[ "$FORCE" -eq 1 ]]; then
    echo "pr-source-remove: force=true overriding sole-evidence check (operator-confirmed)" >&2
    if [[ -n "$AUDIT_LOG" ]]; then
      mkdir -p "$(dirname "$AUDIT_LOG")"
      printf '{"event":"force-remove-pr-source","source":"%s","at":"%s","operator_confirmed":true}\n' "$RM_ID" "$NOW" >> "$AUDIT_LOG"
    fi
  fi

  # Remove from registry.
  REG="$REGISTRY" RM_ID="$RM_ID" LANG="${LANG:-en_US.UTF-8}" ruby -ryaml -e '
  Encoding.default_external = Encoding::UTF_8
  data = YAML.unsafe_load_file(ENV["REG"]) rescue {}
  data["sources"] = (data["sources"] || []).reject { |s| s["id"] == ENV["RM_ID"] }
  data["operator_namespace"] = (data["operator_namespace"] || []).reject { |s| s["id"] == ENV["RM_ID"] }
  File.write(ENV["REG"], YAML.dump(data))
  STDERR.puts "pr-source-remove: removed id=#{ENV["RM_ID"]} from registry=#{ENV["REG"]}"
  '
  exit 0
fi

[[ -z "$ID" || -z "$TREE" ]] && { echo "pr-source-remove: --id and --tree required" >&2; exit 2; }

TARGET=$(grep -rlE "^\s*id:\s*${ID}\s*$" "$TREE" --include="*.yaml" 2>/dev/null | head -1)
[[ -z "$TARGET" ]] && { echo "pr-source-remove: id $ID not found in $TREE" >&2; exit 1; }
NS_DIR=$(dirname "$TARGET")
mkdir -p "$NS_DIR/_archived"
mv "$TARGET" "$NS_DIR/_archived/"
echo "pr-source-remove: archived $TARGET → $NS_DIR/_archived/" >&2
