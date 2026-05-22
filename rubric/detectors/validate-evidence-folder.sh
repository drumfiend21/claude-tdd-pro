#!/usr/bin/env bash
# C-9 SOC 2 evidence-folder validator. Modes:
#   --layout per-control-subdir       evidence dir is org'd as per-control subdirs.
#   --check-non-empty                 every subdir contains at least one artifact.
#   --check-control-id-pattern        subdir names match SOC 2 TSC pattern.
#   --check-coverage [--framework F]  every controls.yaml entry (filtered to F)
#                                     has an evidence subdir.
#   --check-no-orphans                every evidence subdir has a controls.yaml entry.
#   --summary                         prints coverage: <percent>% line.
set -uo pipefail
EVIDENCE_DIR=""; CONTROLS_FILE=""; LAYOUT=""; FRAMEWORK=""
CHECK_NON_EMPTY=0; CHECK_PATTERN=0; CHECK_COVERAGE=0; CHECK_NO_ORPHANS=0; SUMMARY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    --controls-file) CONTROLS_FILE="$2"; shift 2 ;;
    --layout) LAYOUT="$2"; shift 2 ;;
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --check-non-empty) CHECK_NON_EMPTY=1; shift ;;
    --check-control-id-pattern) CHECK_PATTERN=1; shift ;;
    --check-coverage) CHECK_COVERAGE=1; shift ;;
    --check-no-orphans) CHECK_NO_ORPHANS=1; shift ;;
    --summary) SUMMARY=1; shift ;;
    -h|--help) echo "Usage: validate-evidence-folder.sh --evidence-dir <dir> [--controls-file <yaml>] [--layout per-control-subdir] [--check-coverage [--framework F]] [--check-non-empty] [--check-control-id-pattern] [--check-no-orphans] [--summary]" >&2; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$EVIDENCE_DIR" || ! -d "$EVIDENCE_DIR" ]] && { echo "validate-evidence-folder: --evidence-dir <dir> required" >&2; exit 2; }

# Enumerate evidence subdirs.
SUBDIRS=()
for d in "$EVIDENCE_DIR"/*/; do
  [[ -d "$d" ]] || continue
  SUBDIRS+=("$(basename "$d")")
done

# SOC 2 TSC pattern: CC#.#, A#.#, C#.#, PI#.#, P#.#
SOC2_PATTERN='^(CC|PI|P|A|C)[0-9]+\.[0-9]+$'

if [[ "$LAYOUT" == "per-control-subdir" ]]; then
  if [[ ${#SUBDIRS[@]} -eq 0 ]]; then
    echo "validate-evidence-folder: layout=per-control-subdir no subdirs found under $EVIDENCE_DIR" >&2
    exit 1
  fi
  echo "validate-evidence-folder: layout=per-control-subdir subdirs=${#SUBDIRS[@]}" >&2
fi

if [[ "$CHECK_PATTERN" -eq 1 ]]; then
  FAIL=0
  for s in "${SUBDIRS[@]:-}"; do
    [[ -z "$s" ]] && continue
    if ! [[ "$s" =~ $SOC2_PATTERN ]]; then
      echo "validate-evidence-folder: subdir=$s does not match SOC 2 TSC control-id pattern (CC#.#, A#.#, ...)" >&2
      FAIL=1
    fi
  done
  if [[ "$FAIL" -ne 0 ]]; then exit 2; fi
fi

if [[ "$CHECK_NON_EMPTY" -eq 1 ]]; then
  FAIL=0
  for s in "${SUBDIRS[@]:-}"; do
    [[ -z "$s" ]] && continue
    cnt=$(find "$EVIDENCE_DIR/$s" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$cnt" -eq 0 ]]; then
      echo "validate-evidence-folder: subdir=$s empty (no artifacts)" >&2
      FAIL=1
    fi
  done
  if [[ "$FAIL" -ne 0 ]]; then exit 2; fi
fi

# Coverage + orphan + summary checks need controls.yaml.
if [[ "$CHECK_COVERAGE" -eq 1 || "$CHECK_NO_ORPHANS" -eq 1 || "$SUMMARY" -eq 1 ]]; then
  [[ -z "$CONTROLS_FILE" || ! -f "$CONTROLS_FILE" ]] && { echo "validate-evidence-folder: --controls-file required for this mode" >&2; exit 2; }

  # Extract control_ids (optionally filtered by framework).
  CONTROL_IDS=$(CTL="$CONTROLS_FILE" FW="${FRAMEWORK:-}" node -e '
    const fs = require("fs");
    const lines = fs.readFileSync(process.env.CTL, "utf8").split("\n");
    const filter = process.env.FW || "";
    const out = [];
    let cur = null;
    for (const l of lines) {
      const fmw = l.match(/^-\s*framework:\s*(\S+)/);
      if (fmw) { if (cur && cur.control_id && (!filter || cur.framework === filter)) out.push(cur.control_id); cur = { framework: fmw[1] }; continue; }
      const ctl = l.match(/^\s+control_id:\s*(\S+)/);
      if (ctl && cur) cur.control_id = ctl[1];
    }
    if (cur && cur.control_id && (!filter || cur.framework === filter)) out.push(cur.control_id);
    process.stdout.write(out.join("\n"));
  ')

  EV_IDS_LIST=$(printf '%s\n' "${SUBDIRS[@]:-}" | grep -v '^$' || true)

  if [[ "$CHECK_COVERAGE" -eq 1 ]]; then
    FAIL=0
    while IFS= read -r cid; do
      [[ -z "$cid" ]] && continue
      if [[ "$FRAMEWORK" == "soc2-tsc" || -z "$FRAMEWORK" ]]; then
        # When no framework filter applied, only enforce on entries that look like soc2 patterns.
        if [[ -z "$FRAMEWORK" && ! "$cid" =~ $SOC2_PATTERN ]]; then continue; fi
      fi
      if ! echo "$EV_IDS_LIST" | grep -qxF "$cid"; then
        echo "validate-evidence-folder: control_id=$cid missing evidence subdir under $EVIDENCE_DIR" >&2
        FAIL=1
      fi
    done <<< "$CONTROL_IDS"
    if [[ "$FAIL" -ne 0 ]]; then exit 2; fi
  fi

  if [[ "$CHECK_NO_ORPHANS" -eq 1 ]]; then
    FAIL=0
    for s in "${SUBDIRS[@]:-}"; do
      [[ -z "$s" ]] && continue
      if ! echo "$CONTROL_IDS" | grep -qxF "$s"; then
        echo "validate-evidence-folder: subdir=$s orphan (no controls.yaml entry)" >&2
        FAIL=1
      fi
    done
    if [[ "$FAIL" -ne 0 ]]; then exit 2; fi
  fi

  if [[ "$SUMMARY" -eq 1 ]]; then
    TOTAL=$(echo "$CONTROL_IDS" | grep -c . 2>/dev/null || echo 0)
    [[ "$TOTAL" -eq 0 ]] && TOTAL=1
    COVERED=0
    while IFS= read -r cid; do
      [[ -z "$cid" ]] && continue
      if echo "$EV_IDS_LIST" | grep -qxF "$cid"; then
        COVERED=$((COVERED + 1))
      fi
    done <<< "$CONTROL_IDS"
    PCT=$((COVERED * 100 / TOTAL))
    echo "validate-evidence-folder: coverage: ${PCT}% covered=$COVERED total=$TOTAL" >&2
  fi
fi

echo "validate-evidence-folder: ok evidence_dir=$EVIDENCE_DIR" >&2
