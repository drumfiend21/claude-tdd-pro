#!/usr/bin/env bash
# L-11 consolidated anti-poisoning safeguards. Single script with data-driven
# registered checks (no per-check binaries). Modes: --all-checks, --check <name>,
# --list-checks, --dry-run, --enforce, --log <jsonl>.
set -uo pipefail
PATTERN=""; ALL=0; ENFORCE=0; DRY_RUN=0; LOG=""; CHECK=""; LIST=0
REGISTERED="self-approval rapid-merge single-org-cabal"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) PATTERN="$2"; shift 2 ;;
    --all-checks) ALL=1; shift ;;
    --enforce) ENFORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --log) LOG="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --list-checks) LIST=1; shift ;;
    -h|--help) echo "Usage: safeguards.sh --pattern <json> [--all-checks|--check <name>] [--enforce] [--dry-run] [--log <jsonl>] | --list-checks"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$LIST" -eq 1 ]]; then
  for c in $REGISTERED; do echo "safeguards: check=$c" >&2; done
  exit 0
fi

if [[ -n "$CHECK" ]]; then
  found=0
  for c in $REGISTERED; do [[ "$c" == "$CHECK" ]] && found=1; done
  if [[ "$found" -eq 0 ]]; then
    REG_LIST=$(echo $REGISTERED | tr ' ' ',')
    echo "safeguards: unknown_check $CHECK registered_checks=$REG_LIST" >&2
    exit 2
  fi
fi

[[ -z "$PATTERN" || ! -f "$PATTERN" ]] && { echo "safeguards: --pattern required" >&2; exit 2; }

PATTERN="$PATTERN" CHECK="$CHECK" ALL="$ALL" DRY_RUN="$DRY_RUN" ENFORCE="$ENFORCE" LOG="$LOG" node -e '
const fs = require("fs");
const path = require("path");
const j = JSON.parse(fs.readFileSync(process.env.PATTERN, "utf8"));
const prs = j.supporting_prs || [];
const flags = [];

const checks = {
  "self-approval": () => prs.some(p => p.author && p.reviewer && p.author === p.reviewer),
  "rapid-merge": () => prs.some(p => {
    if (!p.opened_at || !p.merged_at) return false;
    return (new Date(p.merged_at) - new Date(p.opened_at)) < 3600 * 1000;
  }),
  "single-org-cabal": () => {
    if (prs.length < 2) return false;
    const orgs = new Set(prs.map(p => p.author_org).filter(Boolean));
    return orgs.size === 1;
  },
};

const all = process.env.ALL === "1";
const single = process.env.CHECK || "";
const toRun = single ? [single] : (all ? Object.keys(checks) : []);
for (const name of toRun) {
  if (checks[name] && checks[name]()) flags.push(name);
}

const dry = process.env.DRY_RUN === "1";
const logPath = process.env.LOG;
const enforce = process.env.ENFORCE === "1";

if (logPath && !dry) {
  fs.mkdirSync(path.dirname(logPath) || ".", { recursive: true });
  if (!fs.existsSync(logPath)) fs.writeFileSync(logPath, "");
}

for (const f of flags) {
  if (dry) {
    process.stderr.write(`safeguards: would_flag=${f} recorded=false blocked=false pattern_id=${j.pattern_id}\n`);
  } else {
    process.stderr.write(`safeguards: flag=${f} pattern_id=${j.pattern_id}\n`);
    if (logPath) {
      const rec = { flag: f, pattern_id: j.pattern_id, at: new Date().toISOString() };
      fs.appendFileSync(logPath, JSON.stringify(rec) + "\n");
    }
  }
}

process.stderr.write(`safeguards: flags_fired=${flags.length} pattern_id=${j.pattern_id}\n`);

if (!dry && enforce && flags.length > 0) {
  process.stderr.write(`safeguards: promotion_blocked=true reason=safeguards_fired flags=${flags.join(",")}\n`);
  process.exit(1);
}
'
