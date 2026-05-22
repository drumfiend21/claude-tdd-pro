#!/usr/bin/env bash
# C-14 compliance sync mechanism (G-9.1 jurisdiction-namespaced).
# Reads COMPLIANCE-URLS.yaml, creates one folder per catalog entry at
# generated-code-quality-standards/<jurisdiction>/<id>/, archives
# entries removed from the catalog (under _meta/archived/), and
# preserves the _operator/ namespace untouched.
set -uo pipefail
CATALOG=""; TARGET=""; DRY=0; SUMMARY=0; ON_REMOVAL="ignore"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog) CATALOG="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --summary) SUMMARY=1; shift ;;
    --on-removal) ON_REMOVAL="$2"; shift 2 ;;
    -h|--help) echo "Usage: sync-from-sources.sh --catalog <yaml> --target <dir> [--dry-run] [--summary] [--on-removal archive|ignore]" >&2; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CATALOG" || ! -f "$CATALOG" ]] && { echo "compliance-sync: --catalog <yaml> required" >&2; exit 2; }
[[ -z "$TARGET" || ! -d "$TARGET" ]] && { echo "compliance-sync: --target <dir> required" >&2; exit 2; }

# Parse catalog entries (id + jurisdiction). Validate required fields
# per §2.19; reject malformed entries with a clear error.
PARSED=$(CAT="$CATALOG" node -e '
  const fs = require("fs");
  const lines = fs.readFileSync(process.env.CAT, "utf8").split("\n");
  let cur = null;
  const entries = [];
  const REQUIRED = ["id", "name", "url", "authoritative_publisher",
    "jurisdiction", "applicable_to", "identifier_scheme",
    "why_authoritative", "fetch_frequency", "legal_review_required",
    "paywalled"];
  function pushCur() {
    if (cur && cur.id) entries.push(cur);
  }
  for (const l of lines) {
    const id = l.match(/^-\s*id:\s*([A-Za-z0-9._-]+)/);
    if (id) {
      pushCur();
      cur = { id: id[1], _raw: {} };
      continue;
    }
    if (!cur) continue;
    const m = l.match(/^\s+([a-z_]+):\s*(.*)$/);
    if (m) {
      cur._raw[m[1]] = (m[2] || "").trim();
    }
  }
  pushCur();
  const errs = [];
  for (const e of entries) {
    for (const f of REQUIRED) {
      if (f === "id") continue;
      if (!(f in e._raw) || e._raw[f] === "") {
        errs.push(`compliance-sync: id=${e.id} missing required field: ${f}`);
        break;
      }
    }
  }
  if (errs.length > 0) {
    process.stderr.write(errs.join("\n") + "\n");
    process.exit(2);
  }
  for (const e of entries) {
    process.stdout.write(`${e.id}\t${e._raw.jurisdiction}\n`);
  }
') || exit 2

CATALOG_IDS=()
declare -a JURISDICTIONS=()
while IFS=$'\t' read -r id juris; do
  [[ -z "$id" ]] && continue
  CATALOG_IDS+=("$id:$juris")
  found=0
  for j in "${JURISDICTIONS[@]:-}"; do
    [[ "$j" == "$juris" ]] && found=1
  done
  [[ "$found" -eq 0 ]] && JURISDICTIONS+=("$juris")
done <<< "$PARSED"

# Scan existing namespaces (skip _operator and _meta) and compute removals.
REMOVALS=()
for nsdir in "$TARGET"/*/; do
  [[ -d "$nsdir" ]] || continue
  ns="$(basename "$nsdir")"
  case "$ns" in _operator|_meta) continue ;; esac
  for sub in "$nsdir"*/; do
    [[ -d "$sub" ]] || continue
    sub_id="$(basename "$sub")"
    # If sub_id not in CATALOG_IDS, it's a removal candidate.
    in_catalog=0
    for entry in "${CATALOG_IDS[@]:-}"; do
      [[ "${entry%%:*}" == "$sub_id" ]] && in_catalog=1
    done
    [[ "$in_catalog" -eq 0 ]] && REMOVALS+=("$ns/$sub_id")
  done
done

ADDED=0
ARCHIVED=0

if [[ "$DRY" -eq 1 ]]; then
  echo "compliance-sync: dry_run=true catalog_entries=${#CATALOG_IDS[@]} planned_removals=${#REMOVALS[@]} (no writes)" >&2
  exit 0
fi

# Create folders for catalog entries.
for entry in "${CATALOG_IDS[@]:-}"; do
  id="${entry%%:*}"
  juris="${entry#*:}"
  dest="$TARGET/$juris/$id"
  if [[ ! -d "$dest" ]]; then
    mkdir -p "$dest"
    ADDED=$((ADDED + 1))
  fi
done

# Handle removals.
if [[ "$ON_REMOVAL" == "archive" ]]; then
  for r in "${REMOVALS[@]:-}"; do
    [[ -z "$r" ]] && continue
    sub_id="${r##*/}"
    src="$TARGET/$r"
    dst="$TARGET/_meta/archived/$sub_id"
    mkdir -p "$TARGET/_meta/archived"
    mv "$src" "$dst"
    ARCHIVED=$((ARCHIVED + 1))
  done
fi

if [[ "$SUMMARY" -eq 1 ]]; then
  echo "compliance-sync: summary: added: $ADDED archived: $ARCHIVED catalog_entries=${#CATALOG_IDS[@]}" >&2
fi

echo "compliance-sync: ok catalog=$CATALOG target=$TARGET entries=${#CATALOG_IDS[@]} added=$ADDED archived=$ARCHIVED" >&2
