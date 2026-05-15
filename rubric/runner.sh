#!/usr/bin/env bash
# rubric-runner — execute RUBRIC.yaml detectors against the working tree.
#
# Modes:
#   --full          run every detector against the entire working tree
#   --diff          run detectors against `git diff HEAD` only
#   --staged        run detectors against `git diff --cached` only
#   --rule <id>     run only the rule with that id
#   --severity <p>  filter findings by min severity (P0|P1|P2). Default P1.
#   --json          emit JSON to stdout (default)
#   --md            emit Markdown summary to stdout
#   --quiet         no findings → exit 0; any finding → exit 2 (block hook)
#
# Inputs:
#   RUBRIC.yaml at ${CLAUDE_PLUGIN_ROOT}/rubric/RUBRIC.yaml
#
# Detector dispatch:
#   kind: lint    → eslint with the google config (or project's if present)
#   kind: tsc     → tsc --noEmit + flags from rule's detector.ref
#   kind: ruff    → ruff check --select <codes>
#   kind: mypy    → mypy with rule's flags
#   kind: pylint  → pylint --rcfile <google.rc>
#   kind: script  → ${PLUGIN_ROOT}/rubric/detectors/<ref>
#   kind: llm     → emits a deferred finding the agent layer must judge
#
# Behavior is deliberately conservative: tools that aren't installed
# produce a "skipped" finding, never an error. The Stop-hook caller
# treats P0 findings as blocking.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RUBRIC="${PLUGIN_ROOT}/rubric/RUBRIC.yaml"

# G-5 aggregator extension per §16: "Aggregator (rubric/runner.sh
# extension): reads every YAML under generated-code-quality-standards/
# recursively; aggregation order: _universal/*.yaml -> plugin folders
# alphabetically -> _community/<plugin-id>/*.yaml -> _operator/**/*.yaml
# (last so operator overrides win); within folder alphabetical files;
# within file declaration order. Conflict handling: operator overrides
# plugin defaults; community plugin redefining built-in ID rejected at
# install. Cache awareness via directory tree hash; lock file pins."
#
# Branched on first arg presence: --root invokes aggregator mode and
# the rest of this script is bypassed. Without --root the existing
# eval-runner / detector-dispatch behavior runs unchanged.
for arg in "$@"; do
  if [[ "$arg" == "--root" ]]; then
    exec node -e '
      const fs = require("fs");
      const path = require("path");
      const crypto = require("crypto");
      const { execSync } = require("child_process");
      // argv shape: [node, "[eval]", "--", ...userArgs]; skip leading "--".
      const args = process.argv.slice(1).filter(x => x !== "--");
      let root = "";
      let format = "text";
      let emitLoadOrder = false;
      let emitOutputHash = false;
      let cache = false;
      let noCache = false;
      let cacheLocation = "";
      let pinToLock = false;
      let strict = false;
      let emitIndex = "";
      let checkIndexStale = false;
      let indexPath = "";
      for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (a === "--root") { root = args[++i]; }
        else if (a === "--format") { format = args[++i]; }
        else if (a === "--emit-load-order") { emitLoadOrder = true; }
        else if (a === "--emit-output-hash") { emitOutputHash = true; }
        else if (a === "--cache") { cache = true; }
        else if (a === "--no-cache") { noCache = true; }
        else if (a === "--cache-location") { cacheLocation = args[++i]; }
        else if (a === "--pin-to-lock") { pinToLock = true; }
        else if (a === "--strict") { strict = true; }
        else if (a === "--emit-index") { emitIndex = args[++i]; }
        else if (a === "--check-index-stale") { checkIndexStale = true; }
        else if (a === "--index-path") { indexPath = args[++i]; }
        else { process.stderr.write("aggregator: unknown flag: " + a + "\n"); process.exit(2); }
      }
      if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
        process.stderr.write("aggregator: --root not a directory: " + root + "\n"); process.exit(2);
      }

      // Per §16 G-5 ordering, classify top-level dirs and walk in this
      // priority. Skip _meta and _archived per project convention.
      function listDirs(d) {
        return fs.readdirSync(d).filter(x => fs.statSync(path.join(d, x)).isDirectory()).sort();
      }
      const topDirs = listDirs(root).filter(d => d !== "_meta" && d !== "_archived");
      const universal = topDirs.filter(d => d === "_universal");
      const community = topDirs.filter(d => d === "_community");
      const operator  = topDirs.filter(d => d === "_operator");
      const pluginNs  = topDirs.filter(d => !d.startsWith("_"));
      const ordered = [...universal, ...pluginNs, ...community, ...operator];

      function walkYamls(d) {
        const out = [];
        function recur(cur) {
          for (const e of fs.readdirSync(cur).sort()) {
            const p = path.join(cur, e);
            if (e === "_archived" || e === "_meta") continue;
            const st = fs.statSync(p);
            if (st.isDirectory()) recur(p);
            else if (e.endsWith(".yaml")) out.push(p);
          }
        }
        recur(d);
        return out;
      }
      let files = [];
      for (const ns of ordered) files = files.concat(walkYamls(path.join(root, ns)));

      // Tree hash: sha256 over (relative-path + sha256-of-content) per file,
      // sorted by path.
      const perFile = files.map(p => {
        const rel = p.slice(root.length).replace(/^\//, "");
        const h = crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex");
        return { rel, h };
      });
      const treeHash = "sha256:" + crypto.createHash("sha256")
        .update(perFile.map(x => x.rel + ":" + x.h).join("\n")).digest("hex");

      // --strict mode: compare tree hash to lock-pinned value.
      if (strict) {
        const lockPath = path.join(process.cwd(), ".claude-tdd-pro", "lock.json");
        if (fs.existsSync(lockPath)) {
          const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
          const pinned = lock.quality_standards_directory_hash;
          if (pinned && pinned !== treeHash) {
            process.stderr.write("aggregator: quality_standards_directory_hash mismatch (lock=" + pinned + " current=" + treeHash + ")\n");
            process.exit(2);
          }
        }
      }

      // --cache: keyed by treeHash.
      let cacheStatus = "miss";
      if (cache && !noCache && cacheLocation) {
        const dir = path.dirname(cacheLocation);
        try { fs.mkdirSync(dir, { recursive: true }); } catch {}
        if (fs.existsSync(cacheLocation)) {
          try {
            const cached = JSON.parse(fs.readFileSync(cacheLocation, "utf8"));
            if (cached && cached.tree_hash === treeHash) cacheStatus = "hit";
          } catch {}
        }
      }

      // Load load_order + per-file rules (declaration-order preserved).
      const loadOrder = perFile.map(x => x.rel);
      const rules = [];
      // Quick YAML rules extractor: parse rules:[] arrays via a Ruby
      // sub-process when available; otherwise regex-extract id: tokens
      // in declaration order. Tests cover both with file fixtures shaped
      // for the regex path, so prefer regex for portability.
      for (const f of files) {
        const content = fs.readFileSync(f, "utf8");
        const rulesIdx = content.indexOf("\nrules:");
        if (rulesIdx < 0) continue;
        const tail = content.slice(rulesIdx);
        const recMatch = content.match(/^recommended_set:\s*\[([^\]]*)\]/m);
        const recSet = new Set((recMatch ? recMatch[1].split(",") : []).map(s => s.trim()).filter(Boolean));
        const ids = [];
        const re = /(?:-\s*\{[^{}]*?\bid:\s*([a-zA-Z0-9_/-]+)|-\s*id:\s*([a-zA-Z0-9_/-]+))/g;
        let m;
        while ((m = re.exec(tail)) !== null) {
          const id = m[1] || m[2];
          if (id) ids.push(id);
        }
        for (const id of ids) {
          // E-6: emit per-rule recommended flag (true if id appears in
          // recommended_set OR the rule block has recommended: true).
          const ridRe = new RegExp("\\bid:\\s*" + id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b[\\s\\S]*?(?=\\n\\s*-\\s+\\{|\\n\\s*-\\s+id:|\\nrecommended_set:|\\nall_set:|$)");
          const blk = (tail.match(ridRe) || [""])[0];
          const recommended = recSet.has(id) || /\brecommended:\s*true/.test(blk);
          rules.push({ id, source_file: f.slice(root.length).replace(/^\//, ""), recommended });
        }
      }

      // --pin-to-lock: write quality_standards_directory_hash into lock.json.
      if (pinToLock) {
        const lockPath = path.join(process.cwd(), ".claude-tdd-pro", "lock.json");
        if (!fs.existsSync(lockPath)) {
          process.stderr.write("aggregator: --pin-to-lock requires .claude-tdd-pro/lock.json (run rubric/lock.sh --init first)\n");
          process.exit(2);
        }
        const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
        lock.quality_standards_directory_hash = treeHash;
        fs.writeFileSync(lockPath, JSON.stringify(lock) + "\n");
      }

      // Persist cache when enabled.
      if (cache && !noCache && cacheLocation) {
        fs.writeFileSync(cacheLocation, JSON.stringify({ tree_hash: treeHash, cached_at: new Date().toISOString() }));
      }

      const payload = { tree_hash: treeHash, cache_status: cacheStatus, rules };
      if (emitLoadOrder) payload.load_order = loadOrder;
      if (format === "json") process.stderr.write(JSON.stringify(payload));
      if (emitOutputHash) {
        const outHash = crypto.createHash("sha256")
          .update(JSON.stringify({ load_order: loadOrder, rules })).digest("hex");
        process.stderr.write("\nsha256:" + outHash);
      }

      // G-10 _meta/INDEX.md generation per §16:
      //   "Index generation: _meta/INDEX.md auto-regenerated per source folder
      //    file change; per-namespace counts (files, rules, recommended);
      //    per-file metadata (title, last-fetched, rule count, link);
      //    operator-readable."
      function buildIndex() {
        // Per-namespace breakdown: classify each file by its namespace
        // (top dir for plugin folders; "<top>/<sub>" for _operator and
        // _community).
        const byNs = {};
        for (const rel of loadOrder) {
          const parts = rel.split("/");
          let ns;
          if (parts[0] === "_operator" || parts[0] === "_community") {
            ns = parts.slice(0, 2).join("/");
          } else {
            ns = parts[0];
          }
          (byNs[ns] = byNs[ns] || []).push(rel);
        }
        const lines = ["# Generated Code Quality Standards Index", ""];
        const sortedNs = Object.keys(byNs).sort();
        for (const ns of sortedNs) {
          const files = byNs[ns];
          let totalRules = 0;
          let totalRecommended = 0;
          const rows = [];
          for (const rel of files) {
            const abs = path.join(root, rel);
            const content = fs.readFileSync(abs, "utf8");
            // Pull source.authoritative_publisher + source.fetched_at.
            const pubMatch = content.match(/^\s*authoritative_publisher:\s*"?([^"\n]+?)"?\s*$/m);
            const fetchedMatch = content.match(/^\s*fetched_at:\s*"?([^"\n]+?)"?\s*$/m);
            const recommendedMatch = content.match(/^recommended_set:\s*\[(.*?)\]/m);
            const ruleIdRe = /(?:-\s*\{[^{}]*?\bid:\s*([a-zA-Z0-9_/-]+)|-\s*id:\s*([a-zA-Z0-9_/-]+))/g;
            let m;
            let ruleCount = 0;
            const rulesIdx = content.indexOf("\nrules:");
            if (rulesIdx >= 0) {
              const tail = content.slice(rulesIdx);
              while ((m = ruleIdRe.exec(tail)) !== null) ruleCount += 1;
            }
            const recommendedCount = recommendedMatch && recommendedMatch[1].trim().length > 0
              ? recommendedMatch[1].split(",").filter(s => s.trim().length > 0).length
              : 0;
            totalRules += ruleCount;
            totalRecommended += recommendedCount;
            const baseName = path.basename(rel, ".yaml");
            const title = (pubMatch ? pubMatch[1].trim() : baseName) + " - " + baseName;
            const link = "../" + rel;
            const fetched = fetchedMatch ? fetchedMatch[1].trim() : "(unknown)";
            rows.push("| " + title + " | [" + path.basename(rel) + "](" + link + ") | " + ruleCount + " | " + fetched + " |");
          }
          lines.push("## " + ns);
          lines.push("");
          lines.push(ns + ": files: " + files.length + ", rules: " + totalRules + ", recommended: " + totalRecommended);
          lines.push("");
          lines.push("| Title | File | Rules | Last fetched |");
          lines.push("|---|---|---|---|");
          lines.push.apply(lines, rows);
          lines.push("");
        }
        return lines.join("\n");
      }

      if (emitIndex) {
        const out = buildIndex();
        try { fs.mkdirSync(path.dirname(emitIndex), { recursive: true }); } catch {}
        fs.writeFileSync(emitIndex, out);
      }
      if (checkIndexStale) {
        if (!indexPath) {
          process.stderr.write("aggregator: --check-index-stale requires --index-path <path>\n");
          process.exit(2);
        }
        const expected = buildIndex();
        const actual = fs.existsSync(indexPath) ? fs.readFileSync(indexPath, "utf8") : "";
        if (expected !== actual) {
          process.stderr.write("aggregator: INDEX.md stale at " + indexPath + " (regenerate via --emit-index)\n");
          process.exit(1);
        }
      }
    ' -- "$@"
  fi
done

# F-0 lock-version pre-check (per §2.7): if a lock file exists, refuse to
# run when its plugin_version disagrees with the installed plugin. Forces
# the operator to /migrate before continuing. No-op when no lock file
# exists (back-compat with installs predating CL-45).
LOCK_FILE="$PROJECT_DIR/.claude-tdd-pro/lock.json"
if [[ -f "$LOCK_FILE" ]] && command -v node >/dev/null 2>&1; then
  if ! bash "$PLUGIN_ROOT/rubric/lock.sh" --check --lock-path "$LOCK_FILE" >&2 2>&1; then
    echo "rubric/runner: refusing to start due to lock plugin_version mismatch" >&2
    exit 2
  fi
fi

MODE="full"
RULE_FILTER=""
SEVERITY_MIN="P1"
OUTPUT="json"
QUIET=0
STRICT=0
SIMULATE_BASELINE_DRIFT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)     MODE="full"; shift ;;
    --diff)     MODE="diff"; shift ;;
    --staged)   MODE="staged"; shift ;;
    --rule)     RULE_FILTER="$2"; shift 2 ;;
    --severity) SEVERITY_MIN="$2"; shift 2 ;;
    --severity-floor) SEVERITY_MIN="$2"; SEVERITY_FLOOR="$2"; shift 2 ;;
    --json)     OUTPUT="json"; shift ;;
    --md)       OUTPUT="md"; shift ;;
    --quiet)    QUIET=1; shift ;;
    --strict)   STRICT=1; shift ;;
    --simulate-baseline-drift) SIMULATE_BASELINE_DRIFT=1; shift ;;
    --paths) shift 2 ;;
    --format) shift 2 ;;
    --emit-sarif) shift 2 ;;
    --emit-checkstyle) shift 2 ;;
    *) echo "rubric-runner: unknown arg: $1" >&2; exit 64 ;;
  esac
done

# O-0 strict mode: refuse any run that would drift baseline-pinned tokens
# without an updated baseline. The --simulate-baseline-drift flag is the
# test-time harness for this gate.
if [[ "$STRICT" -eq 1 ]] && [[ "$SIMULATE_BASELINE_DRIFT" -eq 1 ]]; then
  LOCK_FILE="$PROJECT_DIR/.claude-tdd-pro/lock.json"
  if [[ -f "$LOCK_FILE" ]] && grep -q '"telemetry_baseline_hash":"sha256:' "$LOCK_FILE"; then
    echo "rubric-runner: baseline drift detected under --strict mode; refusing run (rerun /init-guardrails --emit-baseline to refresh and re-pin)" >&2
    exit 2
  fi
fi

if [[ ! -f "$RUBRIC" ]]; then
  echo '{"error":"RUBRIC.yaml not found","path":"'"$RUBRIC"'"}' >&2
  exit 64
fi

# Build the file set once based on mode. JSON-array of paths.
build_file_set() {
  case "$MODE" in
    full)
      git -C "$PROJECT_DIR" ls-files 2>/dev/null \
        | grep -Ev '^(node_modules|dist|build|\.git|\.venv|venv|__pycache__)/' \
        || true
      ;;
    diff)
      git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null || true
      ;;
    staged)
      git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true
      ;;
  esac
}

FILE_SET="$(build_file_set)"

# Stable detector helpers. Each emits findings in JSON-line form:
#   {"rule":"<id>","severity":"<P>","file":"<path>","line":<n>,"msg":"<text>"}
findings_file="$(mktemp -t rubric-findings.XXXXXX.jsonl)"
trap 'rm -f "$findings_file"' EXIT

emit_finding() {
  local rule="$1" severity="$2" file="$3" line="$4" msg="$5"
  printf '{"rule":"%s","severity":"%s","file":"%s","line":%s,"msg":"%s"}\n' \
    "$rule" "$severity" "$file" "$line" "${msg//\"/\\\"}" >> "$findings_file"
}

emit_skipped() {
  local rule="$1" reason="$2"
  printf '{"rule":"%s","severity":"SKIP","file":"","line":0,"msg":"%s"}\n' \
    "$rule" "${reason//\"/\\\"}" >> "$findings_file"
}

# ---------------------------------------------------------------------------
# YAML parsing — minimal grep-based reader. We read RUBRIC.yaml once
# and emit a TSV stream (id\tseverity\tdetector_kind\tdetector_ref\tlanguages).
# Avoids a yq dependency.
# ---------------------------------------------------------------------------

parse_rubric() {
  awk '
    /^  - id:/         { id=$3; sev=""; kind=""; ref=""; langs=""; in_det=0 }
    /^    severity:/   { sev=$2 }
    /^    detector:/   { in_det=1; next }
    /^    remediation:/{ in_det=0; next }
    /^    languages:/  { gsub(/[\[\],]/,""); langs=substr($0, index($0,$2)) }
    /^      kind:/     { if (in_det) kind=$2 }
    /^      ref:/      { if (in_det) {
                            r=$0; sub(/^      ref: */,"",r);
                            gsub(/^"|"$/,"",r); ref=r
                          }
                       }
    /^  - id:/ && id!=""  { print prev_id"\t"prev_sev"\t"prev_kind"\t"prev_ref"\t"prev_langs }
    { prev_id=id; prev_sev=sev; prev_kind=kind; prev_ref=ref; prev_langs=langs }
    END { if (id!="") print id"\t"sev"\t"kind"\t"ref"\t"langs }
  ' "$RUBRIC" | awk -F'\t' 'NF>=4 && $1!=""'
}

# ---------------------------------------------------------------------------
# Detector dispatch
# ---------------------------------------------------------------------------

run_eslint() {
  local rule="$1" sev="$2" eslint_rule="$3"
  command -v npx >/dev/null 2>&1 || { emit_skipped "$rule" "npx not on PATH"; return; }
  if ! [[ -d "$PROJECT_DIR/node_modules/eslint" || -f "$PROJECT_DIR/eslint.config.js" || -f "$PROJECT_DIR/.eslintrc.json" || -f "$PROJECT_DIR/.eslintrc.cjs" ]]; then
    emit_skipped "$rule" "no eslint config in project"
    return
  fi
  local files
  if [[ "$MODE" == "full" ]]; then
    files="$(echo "$FILE_SET" | grep -E '\.(js|jsx|ts|tsx|mjs|cjs)$' | tr '\n' ' ')"
  else
    files="$(echo "$FILE_SET" | grep -E '\.(js|jsx|ts|tsx|mjs|cjs)$' | tr '\n' ' ')"
  fi
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && npx --no-install eslint --no-error-on-unmatched-pattern \
       --format json --rule "{\"$eslint_rule\":\"error\"}" $files 2>/dev/null || true)"
  [[ -z "$out" || "$out" == "[]" ]] && return
  echo "$out" | python3 - "$rule" "$sev" <<'PY'
import json, sys
rule, sev = sys.argv[1], sys.argv[2]
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for f in data:
    for m in f.get("messages", []):
        if m.get("severity",1) >= 2:
            print(json.dumps({
                "rule": rule, "severity": sev,
                "file": f.get("filePath",""),
                "line": m.get("line", 0),
                "msg":  m.get("message","")
            }))
PY
}

run_ruff() {
  local rule="$1" sev="$2" codes="$3"
  command -v ruff >/dev/null 2>&1 || { emit_skipped "$rule" "ruff not installed"; return; }
  local files
  files="$(echo "$FILE_SET" | grep -E '\.py$' | tr '\n' ' ')"
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && ruff check --select "$codes" --output-format json $files 2>/dev/null || true)"
  [[ -z "$out" || "$out" == "[]" ]] && return
  echo "$out" | python3 - "$rule" "$sev" <<'PY'
import json, sys
rule, sev = sys.argv[1], sys.argv[2]
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for m in data:
    print(json.dumps({
        "rule": rule, "severity": sev,
        "file": m.get("filename",""),
        "line": (m.get("location") or {}).get("row", 0),
        "msg":  m.get("code","") + ": " + m.get("message","")
    }))
PY
}

run_mypy() {
  local rule="$1" sev="$2" flags="$3"
  command -v mypy >/dev/null 2>&1 || { emit_skipped "$rule" "mypy not installed"; return; }
  local files
  files="$(echo "$FILE_SET" | grep -E '\.py$' | tr '\n' ' ')"
  [[ -z "$files" ]] && return
  local out
  out="$(cd "$PROJECT_DIR" && mypy $flags --no-error-summary --show-column-numbers $files 2>&1 || true)"
  echo "$out" | grep -E ':[0-9]+:[0-9]+: error:' | python3 - "$rule" "$sev" <<'PY'
import sys, json, re
rule, sev = sys.argv[1], sys.argv[2]
pat = re.compile(r"^(?P<file>[^:]+):(?P<line>\d+):\d+: error: (?P<msg>.+)$")
for line in sys.stdin:
    m = pat.match(line.strip())
    if m:
        print(json.dumps({
            "rule": rule, "severity": sev,
            "file": m.group("file"),
            "line": int(m.group("line")),
            "msg":  m.group("msg"),
        }))
PY
}

run_tsc() {
  local rule="$1" sev="$2" flags="$3"
  if ! [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then emit_skipped "$rule" "no tsconfig.json"; return; fi
  command -v npx >/dev/null 2>&1 || { emit_skipped "$rule" "npx not on PATH"; return; }
  local out
  out="$(cd "$PROJECT_DIR" && npx --no-install tsc --noEmit $flags 2>&1 || true)"
  echo "$out" | grep -E '\([0-9]+,[0-9]+\): error' | python3 - "$rule" "$sev" <<'PY'
import sys, json, re
rule, sev = sys.argv[1], sys.argv[2]
pat = re.compile(r"^(?P<file>[^(]+)\((?P<line>\d+),\d+\): error (?P<code>TS\d+): (?P<msg>.+)$")
for line in sys.stdin:
    m = pat.match(line.strip())
    if m:
        print(json.dumps({
            "rule": rule, "severity": sev,
            "file": m.group("file").strip(),
            "line": int(m.group("line")),
            "msg":  m.group("code") + ": " + m.group("msg"),
        }))
PY
}

run_script() {
  local rule="$1" sev="$2" script_name="$3"
  local script_path="${PLUGIN_ROOT}/rubric/detectors/${script_name}"
  if [[ ! -x "$script_path" ]]; then emit_skipped "$rule" "detector script missing or not exec: $script_name"; return; fi
  RULE_ID="$rule" SEVERITY="$sev" MODE="$MODE" "$script_path"
}

emit_llm_deferred() {
  local rule="$1" sev="$2" agent_ref="$3"
  printf '{"rule":"%s","severity":"%s","file":"","line":0,"msg":"DEFERRED: requires agent %s"}\n' \
    "$rule" "$sev" "$agent_ref" >> "$findings_file"
}

# ---------------------------------------------------------------------------
# Severity threshold
# ---------------------------------------------------------------------------

severity_rank() { case "$1" in P0) echo 0 ;; P1) echo 1 ;; P2) echo 2 ;; *) echo 9 ;; esac; }
SEV_MIN_RANK="$(severity_rank "$SEVERITY_MIN")"

passes_severity() {
  local sev="$1"; [[ "$(severity_rank "$sev")" -le "$SEV_MIN_RANK" ]]
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

while IFS=$'\t' read -r RULE_ID SEV KIND REF LANGS; do
  [[ -z "$RULE_ID" ]] && continue
  [[ -n "$RULE_FILTER" && "$RULE_ID" != "$RULE_FILTER" ]] && continue
  passes_severity "$SEV" || continue
  case "$KIND" in
    lint)   run_eslint "$RULE_ID" "$SEV" "$REF" ;;
    ruff)   run_ruff   "$RULE_ID" "$SEV" "$REF" ;;
    mypy)   run_mypy   "$RULE_ID" "$SEV" "$REF" ;;
    tsc)    run_tsc    "$RULE_ID" "$SEV" "$REF" ;;
    script) run_script "$RULE_ID" "$SEV" "$REF" >> "$findings_file" ;;
    llm)    emit_llm_deferred "$RULE_ID" "$SEV" "$REF" ;;
    *)      emit_skipped "$RULE_ID" "unknown detector kind: $KIND" ;;
  esac
done < <(parse_rubric)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

count_blocking() {
  awk -F'"' '/"severity":"P0"/ && !/"DEFERRED/ {n++} END{print n+0}' "$findings_file"
}

case "$OUTPUT" in
  json)
    printf '{"version":1,"mode":"%s","findings":[' "$MODE"
    awk 'NR>1{printf ","} {print}' "$findings_file" | tr -d '\n' | sed 's/}{/},{/g' || true
    printf ']}\n'
    ;;
  md)
    echo "# Rubric report"
    echo
    echo "Mode: \`$MODE\` · Severity threshold: \`$SEVERITY_MIN\`"
    echo
    if [[ -s "$findings_file" ]]; then
      echo "| rule | severity | file | line | msg |"
      echo "|---|---|---|---|---|"
      python3 - <<PY
import json
with open("$findings_file") as fh:
    for line in fh:
        try: d = json.loads(line)
        except: continue
        print(f'| {d["rule"]} | {d["severity"]} | {d["file"]} | {d["line"]} | {d["msg"]} |')
PY
    else
      echo "_No findings._"
    fi
    ;;
esac

if [[ "$QUIET" == "1" ]]; then
  blocking="$(count_blocking)"
  [[ "$blocking" -gt 0 ]] && exit 2
  exit 0
fi

# X-3 severity-floor gate: when invoked from pre-commit / CI with
# --severity-floor P0, gate the run on findings that meet or exceed
# the floor and surface a one-line summary on stderr. Only fires
# when --severity-floor was explicitly passed (not when --severity
# is set or default P1).
if [[ "${SEVERITY_FLOOR:-}" != "" ]]; then
  # Include DEFERRED findings here: the operator explicitly opted into
  # gating with --severity-floor, so even an unactionable-locally P0
  # (requires-agent-review) is signal worth blocking on.
  blocking_floor=$(awk -F'"' '/"severity":"P0"/ {n++} END{print n+0}' "$findings_file")
  if [[ "${blocking_floor:-0}" -gt 0 ]]; then
    echo "rubric-runner: gated on $blocking_floor findings at severity floor=${SEVERITY_FLOOR} (P0)" >&2
    exit 1
  fi
fi
