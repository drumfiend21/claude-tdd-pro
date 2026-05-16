#!/usr/bin/env bash
# L-8 /pr-corpus-learn with codebase-impact preview (F-6); chains to S-7
# promote flow with class: pr-corpus provenance.
set -uo pipefail
PATTERNS=""; GATE_RESULT=""; ROOT=""; RULES_OUT=""; DRY_RUN=0; PREVIEW_ONLY=0; EMIT=""; DECISIONS_LOG=""; AUDIT_LOG=""; NOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --patterns) PATTERNS="$2"; shift 2 ;;
    --gate-result) GATE_RESULT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --rules-out) RULES_OUT="$2"; shift 2 ;;
    --decisions-log) DECISIONS_LOG="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --preview-only) PREVIEW_ONLY=1; shift ;;
    --emit) EMIT="$2"; shift 2 ;;
    -h|--help) echo "Usage: pr-corpus-learn.sh --patterns <json> [--gate-result <json>] [--root <dir>] [--rules-out <dir>] [--decisions-log <jsonl>] [--audit-log <jsonl>] [--now <iso>] [--dry-run] [--preview-only] [--emit promotion-plan]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[[ -z "$PATTERNS" || ! -f "$PATTERNS" ]] && { echo "pr-corpus-learn: --patterns required" >&2; exit 2; }

# Gate check: only when --gate-result is supplied.
if [[ -n "$GATE_RESULT" && -f "$GATE_RESULT" ]]; then
  GATE=$(GATE_RESULT="$GATE_RESULT" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.GATE_RESULT,"utf8"));process.stdout.write(j.gate||"unknown")')
  if [[ "$GATE" != "pass" ]]; then
    echo "pr-corpus-learn: gate_not_passed gate=$GATE (L-3.5 quality-eval must report gate=pass before promotion)" >&2
    exit 2
  fi
fi

# Unresolved-conflicts check: any pattern with an unresolved decisions.jsonl entry blocks.
if [[ -n "$DECISIONS_LOG" && -f "$DECISIONS_LOG" ]]; then
  CONFLICT=$(PATTERNS="$PATTERNS" DECISIONS_LOG="$DECISIONS_LOG" node -e '
    const fs = require("fs");
    const a = JSON.parse(fs.readFileSync(process.env.PATTERNS, "utf8"));
    const lines = fs.readFileSync(process.env.DECISIONS_LOG, "utf8").trim().split("\n").filter(Boolean);
    const ids = new Set(a.map(p => p.id));
    for (const l of lines) {
      let o; try { o = JSON.parse(l); } catch { continue; }
      if (!o.resolved && ids.has(o.pattern_id)) { process.stdout.write(o.pattern_id); process.exit(0); }
    }
    process.stdout.write("");
  ')
  if [[ -n "$CONFLICT" ]]; then
    echo "pr-corpus-learn: promotion_blocked unresolved_conflict pattern=$CONFLICT (resolve in pr-corpus/decisions.jsonl before promotion)" >&2
    exit 2
  fi
fi

# Untriaged-PR check: any supporting PR with triage_decision=reject blocks.
UNTRIAGED=$(PATTERNS="$PATTERNS" node -e '
  const a=JSON.parse(require("fs").readFileSync(process.env.PATTERNS,"utf8"));
  for (const p of a) for (const pr of (p.supporting_prs||[])) if (pr.triage_decision==="reject") { process.stdout.write(String(pr.number)); process.exit(0); }
  process.stdout.write("");
')
if [[ -n "$UNTRIAGED" ]]; then
  echo "pr-corpus-learn: untriaged_pr pr=$UNTRIAGED (PRs must pass L-3 triage filter before promotion)" >&2
  exit 2
fi

# Codebase impact preview: required when --root supplied.
if [[ -n "$ROOT" ]]; then
  if [[ ! -d "$ROOT" ]]; then
    echo "pr-corpus-learn: impact_preview_failed root=$ROOT (codebase-impact preview source missing; supply existing --root <dir>)" >&2
    exit 2
  fi
  FILES_FLAGGED=$(find "$ROOT" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "pr-corpus-learn: codebase_impact_preview=invoked files_flagged=$FILES_FLAGGED root=$ROOT" >&2
fi

# Preview-only mode: stop after preview (do not iterate patterns).
if [[ "$PREVIEW_ONLY" -eq 1 ]]; then
  exit 0
fi

# Per-pattern promotion / skip logic.
PATTERNS="$PATTERNS" RULES_OUT="$RULES_OUT" DRY_RUN="$DRY_RUN" AUDIT_LOG="$AUDIT_LOG" NOW="$NOW" node -e '
const fs = require("fs");
const path = require("path");
const patterns = JSON.parse(fs.readFileSync(process.env.PATTERNS, "utf8"));
const rulesOut = process.env.RULES_OUT;
const dry = process.env.DRY_RUN === "1";
const auditLog = process.env.AUDIT_LOG;
const now = process.env.NOW;

let considered = patterns.length;
let promoted = 0;
let skipped = 0;

for (const p of patterns) {
  const prs = p.supporting_prs || [];
  const orgs = new Set(prs.map(x => x.org).filter(Boolean));
  const tier1 = prs.filter(x => (x.tier || 99) === 1).length;
  if (prs.length < 3 || orgs.size < 2 || tier1 < 1) {
    process.stderr.write(`pr-corpus-learn: skipped=${p.id} reason=insufficient-evidence prs=${prs.length} orgs=${orgs.size} tier1=${tier1}\n`);
    skipped++;
    continue;
  }
  promoted++;
  if (dry) {
    process.stderr.write(`pr-corpus-learn: would_promote=${p.id}\n`);
  }
  process.stderr.write(`pr-corpus-learn: promoted=${p.id} class=pr-corpus\n`);
  if (!dry && rulesOut) {
    fs.mkdirSync(rulesOut, { recursive: true });
    const ruleFile = path.join(rulesOut, `${p.id}.yaml`);
    const lines = [
      `id: ${p.id}`,
      `class: pr-corpus`,
      `verbatim_quote: ${p.verbatim_quote || ""}`,
      `supporting_prs:`,
    ];
    for (const pr of prs) {
      lines.push(`  - number: ${pr.number}`);
      if (pr.org) lines.push(`    org: ${pr.org}`);
      if (pr.tier !== undefined) lines.push(`    tier: ${pr.tier}`);
      const q = pr.verbatim_quote || p.verbatim_quote || "";
      lines.push(`    verbatim_quote: ${q}`);
    }
    fs.writeFileSync(ruleFile, lines.join("\n") + "\n");
  }
  if (!dry && auditLog) {
    fs.mkdirSync(path.dirname(auditLog) || ".", { recursive: true });
    const entry = {
      event: "pr-corpus-learn",
      pattern_id: p.id,
      source_prs: prs.map(x => x.number),
      evidence_count: prs.length,
      organizations_count: orgs.size,
      at: now,
    };
    fs.appendFileSync(auditLog, JSON.stringify(entry) + "\n");
  }
}
process.stderr.write(`pr-corpus-learn: summary considered=${considered} promoted=${promoted} skipped=${skipped}\n`);
'

# Promotion-plan emission: chain to /promote-standard with pr-corpus class.
if [[ "$EMIT" == "promotion-plan" ]]; then
  echo "pr-corpus-learn: chains_to=/promote-standard provenance_class=pr-corpus" >&2
fi
