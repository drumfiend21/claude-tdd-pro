set -uo pipefail
PATTERNS=""
while [[ $# -gt 0 ]]; do case "$1" in --patterns) PATTERNS="$2"; shift 2 ;; *) shift ;; esac; done
[[ -z "$PATTERNS" || ! -f "$PATTERNS" ]] && { echo "validate-patterns: --patterns required" >&2; exit 2; }
PATTERNS="$PATTERNS" node -e '
const fs = require("fs");
const arr = JSON.parse(fs.readFileSync(process.env.PATTERNS, "utf8"));
if (!Array.isArray(arr)) { process.stderr.write("validate-patterns: not an array\n"); process.exit(2); }
const errs = [];
for (const p of arr) {
  if (!p.verbatim_quote) errs.push(`pattern ${p.id || "?"}: missing verbatim_quote (each pattern must carry an exact-substring quote per L-4 contract)`);
  if (p.usefulness_estimate == null || p.usefulness_estimate < 1 || p.usefulness_estimate > 5) {
    errs.push(`pattern ${p.id || "?"}: usefulness_estimate ${p.usefulness_estimate} must be integer 1-5`);
  }
}
if (errs.length) {
  errs.forEach(e => process.stderr.write(`validate-patterns: ${e}\n`));
  process.exit(2);
}
process.stderr.write(`validate-patterns: all_valid=true count=${arr.length}\n`);
'
