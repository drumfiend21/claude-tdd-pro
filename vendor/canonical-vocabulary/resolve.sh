#!/usr/bin/env bash
# vendor/canonical-vocabulary/resolve.sh - resolve a file to its 4-axis canonical
# vocabulary (ADR-0008, §28.28 Wave 1). The binding primitive the composite engine uses:
# given a path, return the GitHub Linguist language + aliases (by extension) and the IaC
# dialect(s) it matches (by filename / extension+marker / glob). This is how a rule's
# `applies_to.linguist_aliases` / `applies_to.iac_dialects` get matched against a file.
#
# CLI: --file <path> [--json]
# stdout (default): `linguist_aliases=<csv> iac_dialects=<csv>`
# stdout (--json):  a JSON object with the resolved axes
# Exit: 0 ok | 2 usage.

set -uo pipefail
FILE=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: resolve.sh --file <path> [--json]" >&2; exit 0 ;;
    *) echo "resolve: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$FILE" ] && { echo "resolve: --file <path> required" >&2; exit 2; }

VDIR="$(cd "$(dirname "$0")" && pwd -P)"

FILE="$FILE" VDIR="$VDIR" JSON="$JSON" node -e '
  const fs = require("fs"), path = require("path");
  const file = process.env.FILE, vdir = process.env.VDIR, wantJson = process.env.JSON === "1";
  const base = path.basename(file);
  const ext = (base.match(/(\.[^.]+)$/) || [,""])[1].toLowerCase();
  const load = f => { try { return JSON.parse(fs.readFileSync(path.join(vdir, f), "utf8")); } catch (e) { return {}; } };
  const ling = load("linguist-languages.json");
  const iac  = load("iac-dialects.json");

  // axis 1: linguist languages + aliases by extension
  const langs = (ling.by_extension && ling.by_extension[ext]) || [];
  const aliases = [];
  for (const l of langs) {
    aliases.push(l.toLowerCase().replace(/ /g, "-"));
    const m = ling.languages && ling.languages[l];
    if (m && m.aliases) for (const a of m.aliases) aliases.push(a);
  }
  const linguist_aliases = [...new Set(aliases)];

  // axis 4: iac dialects by filename / extension(+marker) / glob
  let content = "";
  try { content = fs.readFileSync(file, "utf8"); } catch (e) {}
  const dialects = [];
  for (const [name, d] of Object.entries(iac.dialects || {})) {
    let hit = false;
    if (d.filenames && d.filenames.includes(base)) hit = true;
    if (!hit && d.globs) for (const g of d.globs) {
      // simple glob: ".../*.ext" or "name/*.ext" — match by suffix segment
      const re = new RegExp(g.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*") + "$");
      if (re.test(file)) hit = true;
    }
    if (!hit && d.extensions && d.extensions.includes(ext)) {
      // extension match requires a marker (if declared) to avoid over-claiming
      if (!d.markers) hit = true;
      else if (d.markers.some(mk => content.includes(mk))) hit = true;
    }
    if (hit) dialects.push(name);
  }

  if (wantJson) {
    process.stdout.write(JSON.stringify({
      file, ext, linguist_languages: langs, linguist_aliases, iac_dialects: dialects
    }));
  } else {
    process.stdout.write("linguist_aliases=" + linguist_aliases.join(",") + " iac_dialects=" + dialects.join(",") + "\n");
  }
'
