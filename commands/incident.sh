#!/usr/bin/env bash
# /incident — F-5 entry point per §16:
#   "/incident <description>: for sideways sessions; drives RUBRIC.yaml/
#    CLAUDE.md additions."
#
# Records a sideways-session incident under incidents/YYYY-MM-DD-NNN/
# with a timeline scaffold, links it back to FAILURE-LOG.md, and
# (with --severity high) recommends /postmortem follow-up to drive
# RUBRIC.yaml / CLAUDE.md additions.
#
# Usage:
#   incident.sh <summary> [--date YYYY-MM-DD] [--link-commit <sha>]
#                          [--interactive] [--severity low|medium|high]
#
# Exit codes (per §2.2):
#   0 — incident recorded
#   2 — usage error (no summary)

set -uo pipefail

SUMMARY=""
DATE=""
LINK_COMMIT=""
INTERACTIVE=0
SEVERITY="medium"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date) DATE="$2"; shift 2 ;;
    --link-commit) LINK_COMMIT="$2"; shift 2 ;;
    --interactive) INTERACTIVE=1; shift ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -*) echo "incident: unknown flag: $1" >&2; exit 2 ;;
    *) [[ -z "$SUMMARY" ]] && SUMMARY="$1" || SUMMARY="$SUMMARY $1"; shift ;;
  esac
done

[[ -z "$SUMMARY" ]] && { echo "incident: <summary> argument required" >&2; exit 2; }
[[ -z "$DATE" ]] && DATE=$(date +%Y-%m-%d)

# §2.14 dry-run: short-circuit before any filesystem writes.
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "incident: dry-run; would record incident on $DATE: $SUMMARY" >&2
  exit 0
fi

# Auto-increment 3-digit suffix per same-date incident.
mkdir -p incidents
SEQ=1
while [[ -d "incidents/${DATE}-$(printf '%03d' "$SEQ")" ]]; do
  SEQ=$((SEQ + 1))
done
INCIDENT_ID="${DATE}-$(printf '%03d' "$SEQ")"
INCIDENT_DIR="incidents/${INCIDENT_ID}"
mkdir -p "$INCIDENT_DIR"

# Author from git config; falls back to "unknown" outside a git repo.
AUTHOR=$(git config user.name 2>/dev/null || echo "unknown")

# Detection mechanism: prompt when --interactive, else placeholder.
DETECTION="(not specified)"
if [[ "$INTERACTIVE" -eq 1 ]]; then
  echo "incident: How was this detected?" >&2
  read -r DETECTION || DETECTION="(not specified)"
fi

# Timeline scaffold.
TIMELINE="$INCIDENT_DIR/timeline.md"
{
  echo "# Incident ${INCIDENT_ID}"
  echo ""
  echo "summary: ${SUMMARY}"
  echo "author: ${AUTHOR}"
  echo "severity: ${SEVERITY}"
  echo "detection: ${DETECTION}"
  echo ""
  echo "## Timeline"
  echo ""
  echo "- T+00:00 — incident recorded via /incident"
  echo ""
  echo "## Impact"
  echo ""
  echo "TODO"
  echo ""
  echo "## Root cause"
  echo ""
  echo "TODO"
  echo ""
  echo "## Remediation"
  echo ""
  echo "TODO"
} > "$TIMELINE"

# Link-commit support: emit a commit-template.txt with Incident-Ref trailer.
if [[ -n "$LINK_COMMIT" ]]; then
  {
    echo ""
    echo "Incident-Ref: ${INCIDENT_ID}"
    echo "Linked-Commit: ${LINK_COMMIT}"
  } > "$INCIDENT_DIR/commit-template.txt"
fi

# Append back-reference entry to FAILURE-LOG.md.
[[ ! -f FAILURE-LOG.md ]] && touch FAILURE-LOG.md
echo "- ${DATE} — ${SUMMARY} → incidents/${INCIDENT_ID}/" >> FAILURE-LOG.md

# Severity gate: high severity recommends /postmortem.
if [[ "$SEVERITY" == "high" ]]; then
  echo "incident: severity=high; /postmortem run recommended to drive rubric/CLAUDE.md additions" >&2
fi

echo "incident: recorded ${INCIDENT_ID} (author=${AUTHOR}, severity=${SEVERITY})" >&2
exit 0
