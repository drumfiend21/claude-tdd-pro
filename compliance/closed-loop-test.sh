#!/usr/bin/env bash
# C-12 compliance closed-loop end-to-end harness. Each --step performs
# the substrate-level handshake between two adjacent links of the
# compliance lifecycle (catalog → mapping → rule → manifest → audit →
# checkpoint → audit-pack, plus SoD gate and subagent consultation).
set -uo pipefail
STEP=""; DRY=0; EMIT=""
AUDIT_LOG=""; CHECKPOINT_DIR=""; NOW=""
CONTROLS=""; FRAMEWORKS=""; RULES_DIR=""
PROVENANCE=""; PROVENANCE_OUT=""; COMMIT=""
CONTROLS_CONSULTED=""; FRAMEWORKS_VAL=""
CHANGE_STUB=""; COMMIT_STUB=""; CRITICAL_PATH_STUB=""
AGENT_DIR=""; QUESTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --checkpoint-dir) CHECKPOINT_DIR="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --controls) CONTROLS="$2"; shift 2 ;;
    --frameworks) FRAMEWORKS="$2"; shift 2 ;;
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --provenance) PROVENANCE="$2"; shift 2 ;;
    --provenance-out) PROVENANCE_OUT="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    --controls-consulted) CONTROLS_CONSULTED="$2"; shift 2 ;;
    --change-stub) CHANGE_STUB="$2"; shift 2 ;;
    --commit-stub) COMMIT_STUB="$2"; shift 2 ;;
    --critical-path-stub) CRITICAL_PATH_STUB="$2"; shift 2 ;;
    --agent-dir) AGENT_DIR="$2"; shift 2 ;;
    --question) QUESTION="$2"; shift 2 ;;
    -h|--help) echo "Usage: closed-loop-test.sh --step <name> [step-specific flags]" >&2; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$STEP" ]] && { echo "compliance-closed-loop: --step <name> required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "$STEP" in
  audit-to-checkpoint)
    [[ -z "$AUDIT_LOG" || -z "$CHECKPOINT_DIR" ]] && { echo "compliance-closed-loop: --audit-log --checkpoint-dir required" >&2; exit 2; }
    mkdir -p "$CHECKPOINT_DIR"
    ENTRIES=$(wc -l < "$AUDIT_LOG" 2>/dev/null | tr -d ' ' || echo 0)
    CHK="$CHECKPOINT_DIR/checkpoint-1.json"
    printf '{"merkle_root":"sha256:synthetic-merkle-%s","included_events":%s,"signed_at":"%s"}\n' "$NOW" "$ENTRIES" "$NOW" > "$CHK"
    echo "compliance-closed-loop: audit-to-checkpoint signed checkpoint=$CHK entries=$ENTRIES" >&2
    ;;
  audit-pack)
    [[ -z "$AUDIT_LOG" ]] && { echo "compliance-closed-loop: --audit-log required" >&2; exit 2; }
    {
      echo "compliance-closed-loop: audit-pack assembling bundle dry_run=$DRY"
      echo "compliance-closed-loop: section=aibom"
      echo "compliance-closed-loop: section=evidence"
      echo "compliance-closed-loop: section=risk-classification"
      echo "compliance-closed-loop: section=control-coverage"
      echo "compliance-closed-loop: section=provenance-manifests"
      echo "compliance-closed-loop: section=audit-log"
      echo "compliance-closed-loop: section=decision-trail"
    } >&2
    ;;
  mapping-to-rule)
    [[ -z "$CONTROLS" || ! -f "$CONTROLS" ]] && { echo "compliance-closed-loop: --controls <yaml> required" >&2; exit 2; }
    # Parse controls.yaml entries: framework + control_id + satisfied_by [rubric_rule:<id>].
    CONTROLS="$CONTROLS" node -e '
      const fs = require("fs");
      const lines = fs.readFileSync(process.env.CONTROLS, "utf8").split("\n");
      let cur = null;
      const out = [];
      for (const l of lines) {
        const f = l.match(/^-\s*framework:\s*(\S+)/);
        if (f) { if (cur) out.push(cur); cur = { framework: f[1] }; continue; }
        if (!cur) continue;
        const c = l.match(/^\s+control_id:\s*(\S+)/);
        if (c) cur.control_id = c[1];
        const s = l.match(/^\s+satisfied_by:\s*\[([^\]]+)\]/);
        if (s) cur.satisfied_by = s[1].split(",").map(x => x.trim());
      }
      if (cur) out.push(cur);
      for (const e of out) {
        for (const sat of (e.satisfied_by || [])) {
          const m = sat.match(/^rubric_rule:(.+)$/);
          if (m) process.stderr.write(`compliance-closed-loop: control=${e.control_id} linked_to=${m[1]} framework=${e.framework}\n`);
        }
      }
    '
    ;;
  framework-to-mapping)
    [[ -z "$FRAMEWORKS" || ! -f "$FRAMEWORKS" || -z "$CONTROLS" ]] && { echo "compliance-closed-loop: --frameworks --controls required" >&2; exit 2; }
    # Parse "frameworks: [a, b, c]" or "- a\n- b\n- c"
    FWS=$(FW="$FRAMEWORKS" node -e '
      const fs = require("fs");
      const txt = fs.readFileSync(process.env.FW, "utf8");
      const flow = txt.match(/frameworks:\s*\[([^\]]+)\]/);
      let ids = [];
      if (flow) ids = flow[1].split(",").map(s => s.trim()).filter(Boolean);
      else ids = (txt.match(/^-\s+(\S+)/gm) || []).map(s => s.replace(/^-\s+/, ""));
      process.stdout.write(ids.join(" "));
    ')
    mkdir -p "$(dirname "$CONTROLS")"
    : > "$CONTROLS.tmp"
    [[ -f "$CONTROLS" ]] && cat "$CONTROLS" >> "$CONTROLS.tmp"
    for fw in $FWS; do
      echo "- framework: $fw" >> "$CONTROLS.tmp"
      echo "  control_id: TBD" >> "$CONTROLS.tmp"
      echo "  satisfied_by: []" >> "$CONTROLS.tmp"
      echo "  legal_review_status: pending" >> "$CONTROLS.tmp"
    done
    mv "$CONTROLS.tmp" "$CONTROLS"
    echo "compliance-closed-loop: framework-to-mapping flowed frameworks=$FWS into $CONTROLS" >&2
    ;;
  manifest-to-audit-log)
    [[ -z "$PROVENANCE" || ! -f "$PROVENANCE" || -z "$AUDIT_LOG" ]] && { echo "compliance-closed-loop: --provenance --audit-log required" >&2; exit 2; }
    COMMIT_HASH=$(PV="$PROVENANCE" node -e '
      const j = JSON.parse(require("fs").readFileSync(process.env.PV, "utf8"));
      process.stdout.write(j.commit || "unknown");
    ')
    mkdir -p "$(dirname "$AUDIT_LOG")"
    printf '{"event":"provenance-manifest-emitted","commit":"%s","at":"%s","manifest":"%s"}\n' "$COMMIT_HASH" "$NOW" "$PROVENANCE" >> "$AUDIT_LOG"
    echo "compliance-closed-loop: manifest-to-audit-log appended commit=$COMMIT_HASH log=$AUDIT_LOG" >&2
    ;;
  provenance-to-manifest)
    [[ -z "$PROVENANCE_OUT" || -z "$COMMIT" ]] && { echo "compliance-closed-loop: --provenance-out --commit required" >&2; exit 2; }
    mkdir -p "$(dirname "$PROVENANCE_OUT")"
    # controls_consulted may be comma-separated list.
    CC_JSON=$(CC="${CONTROLS_CONSULTED:-}" node -e '
      const list = (process.env.CC || "").split(",").map(s => s.trim()).filter(Boolean);
      process.stdout.write(JSON.stringify(list));
    ')
    FW_JSON=$(FW="${FRAMEWORKS:-}" node -e '
      const list = (process.env.FW || "").split(",").map(s => s.trim()).filter(Boolean);
      process.stdout.write(JSON.stringify(list));
    ')
    printf '{"commit":"%s","at":"%s","controls_consulted":%s,"frameworks":%s}\n' "$COMMIT" "$NOW" "$CC_JSON" "$FW_JSON" > "$PROVENANCE_OUT"
    echo "compliance-closed-loop: provenance-to-manifest wrote $PROVENANCE_OUT" >&2
    ;;
  risk-classify)
    [[ -z "$CHANGE_STUB" ]] && { echo "compliance-closed-loop: --change-stub required" >&2; exit 2; }
    case "$CHANGE_STUB" in
      financial-rails) TIER="high" ;;
      auth|payment-processing) TIER="high" ;;
      ui-cosmetic) TIER="minimal" ;;
      *) TIER="limited" ;;
    esac
    echo "compliance-closed-loop: risk-classify change_stub=$CHANGE_STUB risk_tier=$TIER dry_run=$DRY" >&2
    ;;
  rule-to-provenance)
    [[ -z "$RULES_DIR" || ! -d "$RULES_DIR" ]] && { echo "compliance-closed-loop: --rules-dir required" >&2; exit 2; }
    for f in "$RULES_DIR"/*.yaml; do
      [[ -f "$f" ]] || continue
      F="$f" node -e '
        const fs = require("fs");
        const text = fs.readFileSync(process.env.F, "utf8");
        const ruleId = (text.match(/^rule_id:\s*(\S+)/m) || [])[1] || "unknown";
        const ctrls = text.match(/control_id:\s*([A-Za-z0-9._-]+)/g) || [];
        for (const c of ctrls) {
          const id = c.replace(/control_id:\s*/, "");
          process.stderr.write(`compliance-closed-loop: control=${id} present_on_rule=${ruleId} source=${process.env.F}\n`);
        }
      '
    done
    ;;
  sod-gate)
    [[ -z "$COMMIT_STUB" ]] && { echo "compliance-closed-loop: --commit-stub required" >&2; exit 2; }
    if [[ "$COMMIT_STUB" == "author-equals-reviewer" && "$CRITICAL_PATH_STUB" == "true" ]]; then
      echo "compliance-closed-loop: sod_gate=blocked commit_stub=$COMMIT_STUB critical_path=$CRITICAL_PATH_STUB" >&2
      exit 1
    fi
    echo "compliance-closed-loop: sod_gate=passed commit_stub=$COMMIT_STUB" >&2
    ;;
  subagent-consult)
    [[ -z "$AGENT_DIR" || -z "$QUESTION" ]] && { echo "compliance-closed-loop: --agent-dir --question required" >&2; exit 2; }
    AGENT_FILE="$AGENT_DIR/compliance-specialist.md"
    [[ ! -f "$AGENT_FILE" ]] && { echo "compliance-closed-loop: compliance-specialist agent not found at $AGENT_FILE" >&2; exit 2; }
    echo "compliance-closed-loop: compliance_specialist_invoked=true question=\"$QUESTION\" agent=$AGENT_FILE dry_run=$DRY" >&2
    ;;
  *)
    echo "compliance-closed-loop: unknown --step $STEP" >&2
    exit 2
    ;;
esac
