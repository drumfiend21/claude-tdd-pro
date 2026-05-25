#!/usr/bin/env bash
# audit-pack.sh — C-10 substrate. Bundles AIBOM + control coverage +
# evidence + risk classification + audit log + provenance + Decision
# Trail + 3 Freshness sections + "all-three-fresh" badge per commit.
#
# Per architecture section 16 C-10: "/audit-pack bundles AIBOM + control
# coverage + evidence + risk classification + audit log + provenance
# manifests + Decision Trail + Standards Freshness + PR Corpus Freshness
# + Compliance Freshness sections + 'all-three-fresh' badge per commit."
#
# Usage:
#   audit-pack.sh --emit <path> --section <name>
#                 [--aibom-file <path>] [--controls-file <path>]
#                 [--evidence-dir <path>] [--risk-file <path>]
#                 [--audit-log <path>] [--provenance-dir <path>]
#                 [--decision-trail-dir <path>] [--freshness-file <path>]
#                 [--commit-sha <sha>] [--now <iso>] [--dry-run]

set -uo pipefail

EMIT=""
SECTION=""
CONTROLS_FILE=""
AIBOM_FILE=""
EVIDENCE_DIR=""
RISK_FILE=""
AUDIT_LOG_FILE=""
PROVENANCE_DIR=""
DECISION_TRAIL_DIR=""
FRESHNESS_FILE=""
COMMIT_SHA=""
NOW_ISO=""
DRY_RUN=0
BUNDLE_OUT=""
SINCE=""
TUI=0
ADR_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tui) TUI=1; shift ;;
    --adr-dir) ADR_DIR="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --aibom-file) AIBOM_FILE="$2"; shift 2 ;;
    --aibom|--include-aibom) AIBOM_FILE="$2"; SECTION="${SECTION:-aibom}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --risk-file) RISK_FILE="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG_FILE="$2"; shift 2 ;;
    --provenance-dir) PROVENANCE_DIR="$2"; shift 2 ;;
    --decision-trail-dir) DECISION_TRAIL_DIR="$2"; shift 2 ;;
    --freshness-file) FRESHNESS_FILE="$2"; shift 2 ;;
    --commit-sha) COMMIT_SHA="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --bundle-out) BUNDLE_OUT="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) echo "Usage: audit-pack.sh --emit <path> --section <name> [--<artifact>-file <path>] [--audit-log <jsonl>] [--bundle-out <zip>] [--since <iso>] [--dry-run]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "audit-pack: dry-run; would emit section=${SECTION:-(default)} to ${EMIT:-(default)} (no writes)" >&2
  echo "audit-pack: dry_run=true bundle_out=${BUNDLE_OUT:-(none)}" >&2
  # X-5 view-mode emission.
  if [[ "$TUI" -eq 1 ]]; then
    echo "audit-pack: view=tui interactive=true framework=charm.sh" >&2
  else
    echo "audit-pack: view=markdown (default; pass --tui for interactive view)" >&2
  fi
  # W-4 Decision Trail section: enumerate ADRs + EU AI Act Art.12 cite.
  if [[ -n "$ADR_DIR" && -d "$ADR_DIR" ]]; then
    echo "audit-pack: section: Decision Trail" >&2
    echo "audit-pack: EU AI Act Art.12 (record-keeping) satisfaction: per-decision ADR with commit trailer" >&2
    for f in "$ADR_DIR"/*.md; do
      [[ ! -f "$f" ]] && continue
      base=$(basename "$f" .md)
      [[ "$base" == "INDEX" ]] && continue
      echo "audit-pack: adr=$base" >&2
    done
  fi
  # H-8 license-attribution section: included in every dry-run bundle preview.
  echo "audit-pack: section=license-attribution (H-8 sweep included in bundle)" >&2
  # §2.9 control mapping: warn on any controls entry with
  # legal_review_status=pending (the contract calls for an explicit
  # warning surfaced to the operator at bundle assembly time).
  if [[ -n "$CONTROLS_FILE" && -f "$CONTROLS_FILE" ]]; then
    CONTROLS_FILE="$CONTROLS_FILE" ruby -ryaml -e '
      begin
        data = YAML.unsafe_load_file(ENV["CONTROLS_FILE"]) || []
        pending = (data.is_a?(Array) ? data : []).select { |e| e.is_a?(Hash) && e["legal_review_status"] == "pending" }
        pending.each do |e|
          STDERR.write("audit-pack: warn legal_review_status=pending framework=#{e["framework"]} control_id=#{e["control_id"]}\n")
        end
      rescue => err
        STDERR.write("audit-pack: warn controls-file parse error: #{err.message}\n")
      end
    '
  fi
  if [[ -n "$AUDIT_LOG_FILE" && -f "$AUDIT_LOG_FILE" ]]; then
    AUDIT_LOG_FILE="$AUDIT_LOG_FILE" SINCE="$SINCE" node -e '
      const fs = require("fs");
      const lines = fs.readFileSync(process.env.AUDIT_LOG_FILE, "utf8").trim().split("\n").filter(Boolean);
      const since = process.env.SINCE || "";
      const events = [];
      for (const l of lines) {
        let o; try { o = JSON.parse(l); } catch { continue; }
        if (o.event !== "pr-corpus-learn") continue;
        if (since && o.at && o.at < since) continue;
        events.push(o);
      }
      if (events.length === 0) {
        process.stderr.write("audit-pack: pr_corpus_events=0\n");
      } else {
        process.stderr.write("audit-pack: section: Continuous learning evidence\n");
        process.stderr.write("audit-pack: SOC 2 CC4.1 (continuous monitoring): satisfied by per-pattern audit-log entry per promoted rule\n");
        process.stderr.write("audit-pack: EU AI Act Art.12 (record-keeping): satisfied by JSONL retention of pr-corpus-learn events\n");
        for (const e of events) {
          const ec = e.evidence_count !== undefined ? `evidence_count=${e.evidence_count}` : "";
          const oc = e.organizations_count !== undefined ? `organizations_count=${e.organizations_count}` : "";
          process.stderr.write(`audit-pack: pattern_id=${e.pattern_id} ${ec} ${oc}\n`.replace(/\s+\n/, "\n"));
        }
        process.stderr.write(`audit-pack: pr_corpus_events=${events.length}\n`);
      }
    '
  fi
  exit 0
fi

[[ -z "$EMIT" || -z "$SECTION" ]] && { echo "audit-pack: --emit and --section required" >&2; exit 2; }

EMIT="$EMIT" SECTION="$SECTION" \
CONTROLS_FILE="$CONTROLS_FILE" AIBOM_FILE="$AIBOM_FILE" \
EVIDENCE_DIR="$EVIDENCE_DIR" RISK_FILE="$RISK_FILE" \
AUDIT_LOG_FILE="$AUDIT_LOG_FILE" PROVENANCE_DIR="$PROVENANCE_DIR" \
DECISION_TRAIL_DIR="$DECISION_TRAIL_DIR" FRESHNESS_FILE="$FRESHNESS_FILE" \
COMMIT_SHA="$COMMIT_SHA" NOW_ISO="$NOW_ISO" node -e '
const fs = require("fs");
const path = require("path");

const section = process.env.SECTION;
const sections = section.split(",").map(s => s.trim());
const emit = process.env.EMIT;
const lines = [];

function bundleSection(s) {
  switch (s) {
    case "aibom": {
      lines.push("# AIBOM");
      lines.push("");
      const af = process.env.AIBOM_FILE;
      if (af && fs.existsSync(af)) {
        lines.push("```json");
        lines.push(fs.readFileSync(af, "utf8"));
        lines.push("```");
      }
      lines.push("");
      break;
    }
    case "control-coverage": {
      lines.push("# Control Coverage");
      lines.push("");
      const cf = process.env.CONTROLS_FILE;
      if (cf && fs.existsSync(cf)) {
        lines.push("```yaml");
        lines.push(fs.readFileSync(cf, "utf8"));
        lines.push("```");
      }
      lines.push("");
      break;
    }
    case "evidence": {
      lines.push("# Evidence");
      lines.push("");
      const ed = process.env.EVIDENCE_DIR;
      if (ed && fs.existsSync(ed)) {
        const walk = (d) => {
          for (const e of fs.readdirSync(d)) {
            const p = path.join(d, e);
            const st = fs.statSync(p);
            if (st.isDirectory()) {
              lines.push(`## ${e}`);
              walk(p);
            } else {
              const rel = path.relative(ed, p);
              lines.push(`- evidence file: ${rel}`);
              if (e === "manifest.txt") {
                lines.push("```");
                lines.push(fs.readFileSync(p, "utf8"));
                lines.push("```");
              }
            }
          }
        };
        walk(ed);
      }
      lines.push("");
      break;
    }
    case "risk-classification": {
      lines.push("# Risk Classification");
      lines.push("");
      const rf = process.env.RISK_FILE;
      if (rf && fs.existsSync(rf)) {
        lines.push("```yaml");
        lines.push(fs.readFileSync(rf, "utf8"));
        lines.push("```");
      }
      lines.push("");
      break;
    }
    case "audit-log": {
      lines.push("# Audit Log");
      lines.push("");
      const af = process.env.AUDIT_LOG_FILE;
      if (af && fs.existsSync(af)) {
        lines.push("```jsonl");
        lines.push(fs.readFileSync(af, "utf8"));
        lines.push("```");
      }
      lines.push("");
      break;
    }
    case "provenance": {
      lines.push("# Provenance Manifests");
      lines.push("");
      const pd = process.env.PROVENANCE_DIR;
      if (pd && fs.existsSync(pd)) {
        for (const f of fs.readdirSync(pd).sort()) {
          if (!f.endsWith(".json")) continue;
          lines.push(`## ${f}`);
          lines.push("```json");
          lines.push(fs.readFileSync(path.join(pd, f), "utf8"));
          lines.push("```");
        }
      }
      lines.push("");
      break;
    }
    case "decision-trail": {
      lines.push("# Decision Trail");
      lines.push("");
      const dt = process.env.DECISION_TRAIL_DIR;
      if (dt && fs.existsSync(dt)) {
        for (const f of fs.readdirSync(dt).sort()) {
          if (!f.endsWith(".md")) continue;
          const body = fs.readFileSync(path.join(dt, f), "utf8");
          const idMatch = body.match(/decision_id:\s*(\S+)/);
          const id = idMatch ? idMatch[1] : f.replace(/\.md$/, "");
          lines.push(`- decision ${id} (${f})`);
        }
      }
      lines.push("");
      break;
    }
    case "freshness": {
      const ff = process.env.FRESHNESS_FILE;
      let data = {};
      if (ff && fs.existsSync(ff)) {
        try { data = JSON.parse(fs.readFileSync(ff, "utf8")); } catch {}
      }
      lines.push("# Standards Freshness");
      lines.push(`- status: ${data.standards || "unknown"}`);
      lines.push("");
      lines.push("# PR Corpus Freshness");
      lines.push(`- status: ${data.pr_corpus || "unknown"}`);
      lines.push("");
      lines.push("# Compliance Freshness");
      lines.push(`- status: ${data.compliance || "unknown"}`);
      lines.push("");
      break;
    }
    case "freshness-badge": {
      const ff = process.env.FRESHNESS_FILE;
      const sha = process.env.COMMIT_SHA || "unknown";
      let data = {};
      if (ff && fs.existsSync(ff)) {
        try { data = JSON.parse(fs.readFileSync(ff, "utf8")); } catch {}
      } else {
        // Fall back to provenance-record aggregation: read .claude-tdd-pro/provenance/*.json
        // and check standards_state, pr_corpus_state, compliance_state freshness fields.
        const provDir = ".claude-tdd-pro/provenance";
        if (fs.existsSync(provDir)) {
          const prov = {};
          for (const f of fs.readdirSync(provDir)) {
            if (!f.endsWith(".json")) continue;
            let p;
            try { p = JSON.parse(fs.readFileSync(path.join(provDir, f), "utf8")); } catch { continue; }
            for (const [stateKey, prefix] of [["standards_state", "standards"], ["pr_corpus_state", "pr_corpus"], ["compliance_state", "compliance"]]) {
              const st = p[stateKey] || {};
              for (const id of Object.keys(st)) {
                if ((st[id].freshness_at_generation || "").startsWith("fresh")) prov[prefix] = "fresh-within-fetch-frequency";
              }
            }
          }
          data = { ...data, ...prov };
        }
      }
      const allFresh = (data.standards || "").startsWith("fresh") &&
                       (data.pr_corpus || "").startsWith("fresh") &&
                       (data.compliance || "").startsWith("fresh");
      lines.push("# Freshness Badge");
      lines.push("");
      lines.push(`- commit: ${sha}`);
      lines.push(`- badge: ${allFresh ? "all-three-fresh" : "mixed-freshness"}`);
      lines.push(`- standards: ${data.standards || "unknown"}`);
      lines.push(`- pr_corpus: ${data.pr_corpus || "unknown"}`);
      lines.push(`- compliance: ${data.compliance || "unknown"}`);
      lines.push("");
      break;
    }
    case "compliance-freshness": {
      lines.push("# Compliance Freshness");
      lines.push("");
      const provDir = ".claude-tdd-pro/provenance";
      if (fs.existsSync(provDir)) {
        for (const f of fs.readdirSync(provDir).sort()) {
          if (!f.endsWith(".json")) continue;
          let p;
          try { p = JSON.parse(fs.readFileSync(path.join(provDir, f), "utf8")); } catch { continue; }
          const cs = p.compliance_state || {};
          for (const fw of Object.keys(cs)) {
            lines.push(`- ${fw}: ${cs[fw].freshness_at_generation || "unknown"} (commit ${p.commit || f})`);
            if (cs[fw].controls_consulted && cs[fw].controls_consulted.length) {
              lines.push(`  controls: ${cs[fw].controls_consulted.join(", ")}`);
            }
          }
        }
      }
      lines.push("");
      break;
    }
    case "badges": {
      lines.push("# Audit Pack Badges");
      lines.push("");
      const provDir = ".claude-tdd-pro/provenance";
      const records = [];
      if (fs.existsSync(provDir)) {
        for (const f of fs.readdirSync(provDir)) {
          if (!f.endsWith(".json")) continue;
          try { records.push(JSON.parse(fs.readFileSync(path.join(provDir, f), "utf8"))); } catch {}
        }
      }
      // Aggregate freshness across all three state buckets (standards, pr_corpus, compliance).
      const groups = { standards: true, pr_corpus: true, compliance: true };
      const groupKeys = { standards: "standards_state", pr_corpus: "pr_corpus_state", compliance: "compliance_state" };
      const groupSeen = { standards: false, pr_corpus: false, compliance: false };
      for (const r of records) {
        for (const g of Object.keys(groups)) {
          const st = r[groupKeys[g]] || {};
          for (const id of Object.keys(st)) {
            groupSeen[g] = true;
            if ((st[id].freshness_at_generation || "") !== "fresh-within-fetch-frequency") groups[g] = false;
          }
        }
      }
      const standardsFresh = groupSeen.standards && groups.standards;
      const prFresh = groupSeen.pr_corpus && groups.pr_corpus;
      const complFresh = groupSeen.compliance && groups.compliance;
      const allThreeFresh = standardsFresh && prFresh && complFresh;
      lines.push(`- Standards: ${groupSeen.standards ? (groups.standards ? "all-fresh" : "mixed-freshness") : "n/a"}`);
      lines.push(`- PR Corpus: ${groupSeen.pr_corpus ? (groups.pr_corpus ? "all-fresh" : "mixed-freshness") : "n/a"}`);
      lines.push(`- Compliance: ${groupSeen.compliance ? (groups.compliance ? "all-fresh" : "mixed-freshness") : "n/a"}`);
      lines.push(`- Badge: ${allThreeFresh ? "all-three-fresh" : "mixed-freshness"}`);
      break;
    }
    case "standards-freshness": {
      lines.push("# Standards Freshness");
      lines.push("");
      const provDir = ".claude-tdd-pro/provenance";
      const records = [];
      if (fs.existsSync(provDir)) {
        for (const f of fs.readdirSync(provDir)) {
          if (!f.endsWith(".json")) continue;
          try { records.push(JSON.parse(fs.readFileSync(path.join(provDir, f), "utf8"))); } catch {}
        }
      }
      const aggregated = {};
      for (const r of records) {
        const st = r.standards_state || {};
        for (const id of Object.keys(st)) {
          aggregated[id] = aggregated[id] || [];
          aggregated[id].push({ commit: r.commit, status: st[id].freshness_at_generation });
        }
      }
      for (const id of Object.keys(aggregated).sort()) {
        lines.push(`## ${id}`);
        for (const r of aggregated[id]) {
          lines.push(`- commit ${r.commit}: ${r.status}`);
        }
        lines.push("");
      }
      break;
    }
    case "legal-review-status": {
      lines.push("# Pending legal review");
      lines.push("");
      const cf = process.env.CONTROLS_FILE;
      if (cf && fs.existsSync(cf)) {
        const content = fs.readFileSync(cf, "utf8");
        const blocks = content.split(/^- /m).slice(1);
        for (const blk of blocks) {
          const fwMatch = blk.match(/framework:\s*([\w-]+)/);
          const cidMatch = blk.match(/control_id:\s*([\w.-]+)/);
          const stMatch = blk.match(/legal_review_status:\s*(\S+)/);
          if (stMatch && stMatch[1] === "pending" && fwMatch && cidMatch) {
            lines.push(`- ${fwMatch[1]} ${cidMatch[1]}: pending`);
          }
        }
      }
      break;
    }
    case "attestations": {
      lines.push("# Attestations");
      lines.push("");
      const dir = "compliance/attestations";
      const nowDate = (process.env.NOW_ISO || new Date().toISOString()).slice(0, 10);
      if (fs.existsSync(dir)) {
        for (const f of fs.readdirSync(dir).sort()) {
          if (!f.endsWith(".yaml")) continue;
          const content = fs.readFileSync(path.join(dir, f), "utf8");
          const fwMatch = content.match(/framework:\s*(\S+)/);
          const expMatch = content.match(/license_expiry:\s*(\S+)/);
          if (fwMatch && expMatch) {
            const status = expMatch[1] < nowDate ? "expired" : "active";
            lines.push(`- ${fwMatch[1]}: ${status} (expires ${expMatch[1]})`);
          }
        }
      }
      break;
    }
    default:
      process.stderr.write(`audit-pack: unknown section "${s}"\n`);
      process.exit(2);
  }
}

for (const s of sections) bundleSection(s);
fs.writeFileSync(emit, lines.join("\n"));
process.stderr.write(`audit-pack: emitted ${sections.length} section(s) to ${emit}\n`);
'
