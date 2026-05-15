#!/usr/bin/env bash
# rubric/detectors/validate-controls-yaml.sh — C-2 controls.yaml
# validator per §2.9 control mapping.
#
# Schema:
#   - framework: <id>            (required)
#     control_id: <id>           (required)
#     satisfied_by: [<type>|<type>:<ref>]  enum: rubric_rule, hook,
#                                          skill, agent, detector,
#                                          process
#     legal_review_status: pending | exempt | not-applicable |
#                          reviewed_by:<reviewer>:<YYYY-MM-DD>
#
# Usage:
#   validate-controls-yaml.sh <path> [--check-references --tree <dir>]

set -uo pipefail

CONTROLS=""
CHECK_REFS=0
TREE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-references) CHECK_REFS=1; shift ;;
    --tree) TREE="$2"; shift 2 ;;
    -*) echo "validate-controls-yaml: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$CONTROLS" ]] && CONTROLS="$1" || { echo "validate-controls-yaml: unexpected arg: $1" >&2; exit 2; }; shift ;;
  esac
done

[[ -z "$CONTROLS" ]] && { echo "validate-controls-yaml: <path> required" >&2; exit 2; }
[[ ! -f "$CONTROLS" ]] && { echo "validate-controls-yaml: file not found: $CONTROLS" >&2; exit 2; }

CONTROLS="$CONTROLS" CHECK_REFS="$CHECK_REFS" TREE="$TREE" node -e '
  const fs = require("fs");
  const path = require("path");
  const content = fs.readFileSync(process.env.CONTROLS, "utf8");
  const errs = [];
  const satisfiedTypes = ["rubric_rule", "hook", "skill", "agent", "detector", "process"];
  const statusEnum = ["pending", "exempt", "not-applicable"];

  let ruleIds = null;
  if (process.env.CHECK_REFS === "1" && process.env.TREE) {
    ruleIds = new Set();
    function walk(d) {
      if (!fs.existsSync(d)) return;
      for (const e of fs.readdirSync(d)) {
        const p = path.join(d, e);
        const st = fs.statSync(p);
        if (st.isDirectory()) walk(p);
        else if (e.endsWith(".yaml")) {
          const c = fs.readFileSync(p, "utf8");
          const re = /\bid:\s*([a-zA-Z0-9_\/-]+)/g;
          let m; while ((m = re.exec(c)) !== null) ruleIds.add(m[1]);
        }
      }
    }
    walk(process.env.TREE);
  }

  // Regex-based per-entry extraction (avoids Psych errors on flow-style
  // arrays containing colon-bearing scalars like [rubric_rule:g-x-001]).
  const blocks = content.split(/^- /m).slice(1);
  blocks.forEach((blk, idx) => {
    const fwMatch = blk.match(/^framework:\s*(\S+)/m);
    const cidMatch = blk.match(/^\s*control_id:\s*(\S+)/m);
    const sbMatch = blk.match(/^\s*satisfied_by:\s*\[([^\]]*)\]/m);
    const lrsMatch = blk.match(/^\s*legal_review_status:\s*(\S+)/m);
    const label = cidMatch ? cidMatch[1] : `(#${idx})`;
    if (!fwMatch) errs.push(`entry ${label}: framework required`);
    if (!cidMatch) errs.push(`entry ${label}: control_id required`);
    if (sbMatch) {
      const items = sbMatch[1].split(",").map(s => s.trim()).filter(Boolean);
      for (const sb of items) {
        const type = sb.split(":")[0];
        if (!satisfiedTypes.includes(type)) {
          errs.push(`entry ${label}: satisfied_by "${sb}" not in enum {${satisfiedTypes.join(", ")}}`);
          continue;
        }
        if (ruleIds && type === "rubric_rule") {
          const rid = sb.split(":")[1];
          if (rid && !ruleIds.has(rid)) {
            errs.push(`entry ${label}: satisfied_by "${sb}" dangling - rule ${rid} not present in --tree`);
          }
        }
      }
    }
    if (lrsMatch) {
      const s = lrsMatch[1];
      if (statusEnum.includes(s)) {
        // ok
      } else if (s.startsWith("reviewed_by:")) {
        const parts = s.split(":");
        if (parts.length !== 3 || !/^\d{4}-\d{2}-\d{2}$/.test(parts[2])) {
          errs.push(`entry ${label}: legal_review_status reviewed_by must be reviewed_by:<reviewer>:<YYYY-MM-DD> (got "${s}"; date format invalid)`);
        }
      } else {
        errs.push(`entry ${label}: legal_review_status "${s}" not in enum`);
      }
    }
  });

  if (errs.length === 0) process.exit(0);
  errs.forEach(e => process.stderr.write(e + "\n"));
  process.exit(2);
'
