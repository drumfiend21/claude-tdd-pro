#!/usr/bin/env bash
# standards/freshness-gate.sh — S-13 daily-fresh fetch guarantee per §16:
#   "Daily-fresh fetch guarantee (per-operation gate + first-use-of-day)."
#
# Per §2.17 live freshness contract status enum:
#   fresh-within-fetch-frequency | stale-warn-degraded | offline-cached
#   | operator-bypass
#
# Markers:
#   .claude-tdd-pro/standards-last-fetch/<source-id>.txt   ISO timestamp
#   .claude-tdd-pro/standards-last-fuod/<YYYY-MM-DD>.txt   marker file
#   .claude-tdd-pro/standards-cache/<source-id>.html       cached content
#
# Usage:
#   freshness-gate.sh --source-id <id> --fetch-frequency <freq>
#                     --now <iso> [--upstream-stub <path>] [--no-network]
#                     [--strict] [--skip-fresh] [--emit-status <path>]
#                     [--emit-audit <jsonl>]
#   freshness-gate.sh --check-first-use-of-day --now <iso>
#                     --upstream-stub <path>
#
# Exit: 0 fresh / 1 stale (blocked) / 2 strict-mode hard fail.

set -uo pipefail

# §2.17 dual-mode dispatch: when --operation is in args, run the §2.17
# live-freshness-gate handler against the standards last-fetch dir.
# Otherwise fall through to the legacy S-13 daily-fresh implementation.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
if [ -f "$PLUGIN_ROOT/lib/freshness-gate-217.sh" ]; then
  # shellcheck disable=SC1091
  . "$PLUGIN_ROOT/lib/freshness-gate-217.sh"
  F217_LAST_FETCH_DIR=".claude-tdd-pro/standards/last-fetch"
  f217_detect_and_run "$@"
fi

SOURCE_ID=""
FETCH_FREQUENCY=""
NOW_ISO=""
UPSTREAM_STUB=""
NO_NETWORK=0
STRICT=0
SKIP_FRESH=0
EMIT_STATUS=""
EMIT_AUDIT=""
CHECK_FUOD=0
APPLY_TO_RULES=0
TREE=""
EMIT_APPLIED=""
DRY_RUN=0
UPDATE_SOURCE_FILES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-id) SOURCE_ID="$2"; shift 2 ;;
    --fetch-frequency) FETCH_FREQUENCY="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --upstream-stub) UPSTREAM_STUB="$2"; shift 2 ;;
    --no-network) NO_NETWORK=1; shift ;;
    --strict) STRICT=1; shift ;;
    --skip-fresh) SKIP_FRESH=1; shift ;;
    --emit-status) EMIT_STATUS="$2"; shift 2 ;;
    --emit-audit) EMIT_AUDIT="$2"; shift 2 ;;
    --check-first-use-of-day) CHECK_FUOD=1; shift ;;
    --apply-to-rules) APPLY_TO_RULES=1; shift ;;
    --tree) TREE="$2"; shift 2 ;;
    --emit-applied) EMIT_APPLIED="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --update-source-files) UPDATE_SOURCE_FILES=1; shift ;;
    *) echo "freshness-gate: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# S-16 apply-to-rules mode: walk tree, demote/restore rules based on
# their provenance sources freshness.
if [[ "$APPLY_TO_RULES" -eq 1 ]]; then
  [[ -z "$TREE" ]] && { echo "freshness-gate --apply-to-rules: --tree required" >&2; exit 2; }
  [[ -z "$NOW_ISO" ]] && { echo "freshness-gate --apply-to-rules: --now required" >&2; exit 2; }
  mkdir -p .claude-tdd-pro/standards-last-fetch
  TREE="$TREE" NOW_ISO="$NOW_ISO" STRICT="$STRICT" EMIT_APPLIED="$EMIT_APPLIED" \
  EMIT_AUDIT="$EMIT_AUDIT" DRY_RUN="$DRY_RUN" UPDATE_SOURCE_FILES="$UPDATE_SOURCE_FILES" node -e '
    const fs = require("fs");
    const path = require("path");
    const tree = process.env.TREE;
    const now = new Date(process.env.NOW_ISO).getTime();
    const strict = process.env.STRICT === "1";
    const emitApplied = process.env.EMIT_APPLIED;
    const emitAudit = process.env.EMIT_AUDIT;
    const dryRun = process.env.DRY_RUN === "1";
    const updateSourceFiles = process.env.UPDATE_SOURCE_FILES === "1";

    function walk(d) {
      const out = [];
      if (!fs.existsSync(d)) return out;
      for (const e of fs.readdirSync(d).sort()) {
        const p = path.join(d, e);
        if (e === "_meta" || e === "_archived") continue;
        const st = fs.statSync(p);
        if (st.isDirectory()) out.push(...walk(p));
        else if (e.endsWith(".yaml")) out.push(p);
      }
      return out;
    }
    const files = walk(tree);

    const demoStatePath = ".claude-tdd-pro/freshness-demotions.json";
    let demoState = {};
    if (fs.existsSync(demoStatePath)) {
      try { demoState = JSON.parse(fs.readFileSync(demoStatePath, "utf8")); } catch {}
    }

    function checkSourceFresh(srcId) {
      const m = `.claude-tdd-pro/standards-last-fetch/${srcId}.txt`;
      if (!fs.existsSync(m)) return false;
      const t = new Date(fs.readFileSync(m, "utf8").trim()).getTime();
      const ageHours = (now - t) / 3600000;
      return ageHours <= 24;
    }

    const applied = {};
    for (const f of files) {
      const c = fs.readFileSync(f, "utf8");
      const rulesIdx = c.indexOf("\nrules:");
      if (rulesIdx < 0) continue;
      const tail = c.slice(rulesIdx);
      const ruleRe = /\bid:\s*([a-zA-Z0-9_/-]+)[\s\S]*?\bprovenance:\s*\[([\s\S]*?)\](?=\s*\}|\s*\n\s*-\s+id:|\s*\Z)/g;
      let m;
      while ((m = ruleRe.exec(tail)) !== null) {
        const rid = m[1];
        const provBody = m[2];
        const ruleStateMatch = m[0].match(/\brule_state:\s*([a-zA-Z_-]+)/);
        const ruleState = ruleStateMatch ? ruleStateMatch[1] : "block";
        const histMatch = m[0].match(/\brule_state_history:\s*\[([\s\S]*?)\]/);
        const operatorExplicit = histMatch && /reason:\s*operator-explicit/.test(histMatch[1]);

        const provEntries = [];
        const entryRe = /\{([^{}]*)\}/g;
        let em;
        while ((em = entryRe.exec(provBody)) !== null) {
          const cm = em[1].match(/\bclass:\s*([a-zA-Z-]+)/);
          const sm = em[1].match(/\bsource:\s*([a-zA-Z0-9_-]+)/);
          if (cm && sm) provEntries.push({ class: cm[1], source: sm[1] });
        }
        const standardsEntries = provEntries.filter(p => p.class !== "pr-corpus" && p.class !== "community-plugin");
        if (standardsEntries.length === 0) continue;

        const allStale = standardsEntries.every(p => !checkSourceFresh(p.source));

        if (allStale) {
          if (operatorExplicit) continue;
          const newState = strict ? "disabled" : "warn-only";
          if (dryRun) {
            applied[rid] = { action: "would demote", from: ruleState, to: newState };
          } else {
            applied[rid] = { action: strict ? "disabled" : "auto-demoted", from: ruleState, to: newState };
            demoState[rid] = { original: ruleState, demoted: newState, reason: "freshness-stale" };
            if (updateSourceFiles) {
              const updated = c.replace(`id: ${rid}`, `id: ${rid}, status_note: freshness-stale`);
              fs.writeFileSync(f, updated);
            }
          }
        } else if (demoState[rid] && !operatorExplicit) {
          applied[rid] = { action: "auto-restored", from: ruleState, to: demoState[rid].original };
          if (!dryRun) delete demoState[rid];
        }
      }
    }

    if (!dryRun) {
      fs.writeFileSync(demoStatePath, JSON.stringify(demoState, null, 2));
    }
    if (emitApplied) {
      fs.mkdirSync(path.dirname(emitApplied) || ".", { recursive: true });
      fs.writeFileSync(emitApplied, JSON.stringify(applied, null, 2));
    }
    if (emitAudit) {
      fs.mkdirSync(path.dirname(emitAudit), { recursive: true });
      for (const rid of Object.keys(applied)) {
        const a = applied[rid];
        const action = a.action === "auto-demoted" ? "rule-auto-demoted" : (a.action === "auto-restored" ? "rule-auto-restored" : "rule-state-change");
        fs.appendFileSync(emitAudit, JSON.stringify({ rule_id: rid, action, from: a.from, to: a.to, ts: process.env.NOW_ISO }) + "\n");
      }
    }
    for (const rid of Object.keys(applied)) {
      const a = applied[rid];
      process.stderr.write(`freshness-gate: ${a.action} ${rid} (${a.from} -> ${a.to})\n`);
    }
    process.exit(0);
  '
  exit $?
fi

[[ -z "$NOW_ISO" ]] && { echo "freshness-gate: --now <iso> required" >&2; exit 2; }
mkdir -p .claude-tdd-pro/standards-last-fetch .claude-tdd-pro/standards-last-fuod

# First-use-of-day mode.
if [[ "$CHECK_FUOD" -eq 1 ]]; then
  TODAY=$(echo "$NOW_ISO" | cut -dT -f1)
  MARKER=".claude-tdd-pro/standards-last-fuod/${TODAY}.txt"
  if [[ -f "$MARKER" ]]; then
    echo "freshness-gate: already refreshed today (${TODAY}); skipping first-use-of-day" >&2
    exit 0
  fi
  echo "freshness-gate: first use of day (${TODAY}); auto-refresh kicked off" >&2
  if [[ -n "$UPSTREAM_STUB" && -x "$UPSTREAM_STUB" ]]; then
    "$UPSTREAM_STUB" >/dev/null 2>&1 || true
  fi
  echo "$NOW_ISO" > "$MARKER"
  exit 0
fi

# Per-operation gate mode.
[[ -z "$SOURCE_ID" ]] && { echo "freshness-gate: --source-id <id> required" >&2; exit 2; }
[[ -z "$FETCH_FREQUENCY" ]] && { echo "freshness-gate: --fetch-frequency required" >&2; exit 2; }

SOURCE_ID="$SOURCE_ID" FETCH_FREQUENCY="$FETCH_FREQUENCY" NOW_ISO="$NOW_ISO" \
UPSTREAM_STUB="$UPSTREAM_STUB" NO_NETWORK="$NO_NETWORK" STRICT="$STRICT" \
SKIP_FRESH="$SKIP_FRESH" EMIT_STATUS="$EMIT_STATUS" EMIT_AUDIT="$EMIT_AUDIT" node -e '
  const fs = require("fs");
  const path = require("path");
  const { execSync } = require("child_process");
  const id = process.env.SOURCE_ID;
  const ff = process.env.FETCH_FREQUENCY;
  const now = new Date(process.env.NOW_ISO).getTime();
  const upstream = process.env.UPSTREAM_STUB;
  const noNetwork = process.env.NO_NETWORK === "1";
  const strict = process.env.STRICT === "1";
  const skipFresh = process.env.SKIP_FRESH === "1";
  const emitStatus = process.env.EMIT_STATUS;
  const emitAudit = process.env.EMIT_AUDIT;

  const windowHours = { hourly: 1, daily: 24, weekly: 168, monthly: 720 }[ff];
  if (!windowHours) {
    process.stderr.write(`freshness-gate: unknown fetch-frequency \"${ff}\"\n`);
    process.exit(2);
  }

  const markerPath = `.claude-tdd-pro/standards-last-fetch/${id}.txt`;
  let lastFetch = null;
  if (fs.existsSync(markerPath)) {
    lastFetch = new Date(fs.readFileSync(markerPath, "utf8").trim()).getTime();
  }
  const ageHours = lastFetch ? (now - lastFetch) / 3600000 : Infinity;
  const isFresh = ageHours <= windowHours;

  let status;
  let exitCode = 0;

  if (skipFresh) {
    status = "operator-bypass";
    if (emitAudit) {
      fs.mkdirSync(path.dirname(emitAudit), { recursive: true });
      fs.appendFileSync(emitAudit,
        JSON.stringify({ source_id: id, ts: process.env.NOW_ISO, action: "skip-fresh", note: "operator bypass via --skip-fresh" }) + "\n");
    }
    exitCode = 0;
  } else if (isFresh) {
    status = "fresh-within-fetch-frequency";
    exitCode = 0;
  } else {
    // Stale. Try to refresh unless --no-network.
    if (!noNetwork && upstream && fs.existsSync(upstream)) {
      try {
        execSync(`"${upstream}"`, { stdio: "ignore" });
        fs.writeFileSync(markerPath, process.env.NOW_ISO);
        status = "fresh-within-fetch-frequency";
        exitCode = 0;
      } catch {
        // Upstream failed.
        const cachePath = `.claude-tdd-pro/standards-cache/${id}.html`;
        if (fs.existsSync(cachePath)) {
          status = "offline-cached";
          exitCode = 0;
        } else {
          status = "stale-warn-degraded";
          process.stderr.write(`freshness-gate: source ${id} stale (age ${Math.round(ageHours)}h, ${ff} window ${windowHours}h); upstream failed; warn-degraded\n`);
          exitCode = strict ? 2 : 0;
          if (strict) process.stderr.write(`freshness-gate: --strict mode rejects stale-warn-degraded\n`);
        }
      }
    } else if (noNetwork) {
      const cachePath = `.claude-tdd-pro/standards-cache/${id}.html`;
      if (fs.existsSync(cachePath)) {
        status = "offline-cached";
        exitCode = 0;
      } else {
        status = "stale-warn-degraded";
        process.stderr.write(`freshness-gate: source ${id} stale (no-network, no cache)\n`);
        exitCode = strict ? 2 : 1;
      }
    } else {
      status = "stale";
      process.stderr.write(`freshness-gate: source ${id} stale (age ${Math.round(ageHours)}h, ${ff} window ${windowHours}h); refresh required\n`);
      exitCode = 1;
    }
  }

  if (emitStatus) {
    fs.mkdirSync(path.dirname(emitStatus), { recursive: true });
    fs.writeFileSync(emitStatus, JSON.stringify({ source_id: id, freshness_at_generation: status, age_hours: Math.round(ageHours), now: process.env.NOW_ISO }));
  }
  process.exit(exitCode);
'
