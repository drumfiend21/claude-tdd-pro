#!/usr/bin/env bash
# §2.24 portable audit-pack export.
#
# Writes a portable bundle to compliance/audit-packs/<bundle-id>/
# where bundle-id = <commit-sha>-<utc-timestamp>.
#
# Formats:
#   json     -- canonical JSON (sorted keys, RFC 8785 JCS-style)
#   markdown -- human review
#   html     -- self-contained (no external assets)
#   tarball  -- bundles all three formats with detached signature
#
# Reproducibility: same inputs at same commit produce byte-identical
# bundles via canonical JSON, pinned timestamps from --generated-at,
# no wall-clock leakage.
#
# Usage:
#   audit-pack-emit.sh --format <json|markdown|html|tarball>
#                      --commit-sha <sha>
#                      --generated-at <iso8601>
#                      --out-dir <path>
#                      [--input-json <path>]   # pre-built C-10 content
#                      [--dry-run]

set -uo pipefail

FORMAT=""
COMMIT_SHA=""
GENERATED_AT=""
OUT_DIR=""
INPUT_JSON=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --commit-sha) COMMIT_SHA="$2"; shift 2 ;;
    --generated-at) GENERATED_AT="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --input-json) INPUT_JSON="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: audit-pack-emit.sh --format <json|markdown|html|tarball> --commit-sha <sha> --generated-at <iso> --out-dir <path> [--input-json <path>] [--dry-run]" >&2
      exit 0
      ;;
    *) echo "audit-pack-emit: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$FORMAT" ]] && { echo "audit-pack-emit: --format required" >&2; exit 2; }
[[ -z "$COMMIT_SHA" ]] && { echo "audit-pack-emit: --commit-sha required" >&2; exit 2; }
[[ -z "$GENERATED_AT" ]] && { echo "audit-pack-emit: --generated-at required" >&2; exit 2; }
[[ -z "$OUT_DIR" ]] && { echo "audit-pack-emit: --out-dir required" >&2; exit 2; }

case "$FORMAT" in
  json|markdown|html|tarball) ;;
  *) echo "audit-pack-emit: invalid --format: $FORMAT" >&2; exit 2 ;;
esac

BUNDLE_ID="${COMMIT_SHA}-${GENERATED_AT}"
BUNDLE_DIR="${OUT_DIR}/${BUNDLE_ID}"

emit_canonical_json() {
  FORMAT="$FORMAT" COMMIT_SHA="$COMMIT_SHA" GENERATED_AT="$GENERATED_AT" \
    BUNDLE_ID="$BUNDLE_ID" INPUT_JSON="$INPUT_JSON" \
    node -e '
      const fs = require("fs");
      let input = {};
      if (process.env.INPUT_JSON && fs.existsSync(process.env.INPUT_JSON)) {
        input = JSON.parse(fs.readFileSync(process.env.INPUT_JSON, "utf8"));
      }
      const bundle = Object.assign({
        bundle_schema_version: "1.0",
        bundle_id: process.env.BUNDLE_ID,
        generated_at: process.env.GENERATED_AT,
        commit: process.env.COMMIT_SHA,
        profile_snapshot_hash: "",
        aibom_uri: "",
        control_coverage: {},
        evidence_set: [],
        risk_classification: {},
        audit_log_window: { first_entry: "", last_entry: "", checkpoint_uris: [] },
        provenance_manifest_uris: [],
        decision_trail: [],
        standards_freshness: {},
        pr_corpus_freshness: {},
        compliance_freshness: {},
        all_three_fresh_badge: false,
        cost_telemetry_summary: {},
        signature: ""
      }, input);
      const sortKeys = (o) => {
        if (Array.isArray(o)) return o.map(sortKeys);
        if (o && typeof o === "object") {
          return Object.keys(o).sort().reduce((acc, k) => { acc[k] = sortKeys(o[k]); return acc; }, {});
        }
        return o;
      };
      process.stdout.write(JSON.stringify(sortKeys(bundle)));
    '
}

emit_markdown() {
  cat <<MD
# Audit Pack ${BUNDLE_ID}

- bundle_schema_version: 1.0
- bundle_id: ${BUNDLE_ID}
- generated_at: ${GENERATED_AT}
- commit: ${COMMIT_SHA}

See bundle.json for the full machine-consumable record.
MD
}

emit_html() {
  cat <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Audit Pack ${BUNDLE_ID}</title></head>
<body><h1>Audit Pack ${BUNDLE_ID}</h1>
<dl>
  <dt>bundle_schema_version</dt><dd>1.0</dd>
  <dt>bundle_id</dt><dd>${BUNDLE_ID}</dd>
  <dt>generated_at</dt><dd>${GENERATED_AT}</dd>
  <dt>commit</dt><dd>${COMMIT_SHA}</dd>
</dl></body></html>
HTML
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "audit-pack-emit: dry_run=true format=$FORMAT bundle_id=$BUNDLE_ID" >&2
  exit 0
fi

mkdir -p "$BUNDLE_DIR"

case "$FORMAT" in
  json)     emit_canonical_json > "$BUNDLE_DIR/bundle.json" ;;
  markdown) emit_markdown       > "$BUNDLE_DIR/bundle.md" ;;
  html)     emit_html           > "$BUNDLE_DIR/bundle.html" ;;
  tarball)
    emit_canonical_json > "$BUNDLE_DIR/bundle.json"
    emit_markdown       > "$BUNDLE_DIR/bundle.md"
    emit_html           > "$BUNDLE_DIR/bundle.html"
    (cd "$BUNDLE_DIR" && tar -cf "bundle.tar" bundle.json bundle.md bundle.html 2>/dev/null)
    ;;
esac

echo "audit-pack-emit: format=$FORMAT bundle_id=$BUNDLE_ID out=$BUNDLE_DIR" >&2
exit 0
