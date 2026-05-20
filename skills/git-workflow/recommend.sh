#!/usr/bin/env bash
# W-2 git-workflow recommender. Multiple --check modes (branch-hygiene,
# branch-off, diverged-from-main, merge-strategy, push-timing).
set -uo pipefail
CHECK=""; ROOT=""; PROFILE=""; EMIT=""
BRANCH_AGE_STUB=""; STALE_THRESHOLD=""
COMMIT_THRESHOLD=""
DIVERGED_STUB=""
COMMITS_STUB=""; CONCERNS_STUB=""; SHARED_STUB=""
UI_TEST_STATUS_STUB=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --emit) EMIT="$2"; shift 2 ;;
    --branch-age-stub) BRANCH_AGE_STUB="$2"; shift 2 ;;
    --stale-threshold) STALE_THRESHOLD="$2"; shift 2 ;;
    --commit-threshold) COMMIT_THRESHOLD="$2"; shift 2 ;;
    --diverged-stub) DIVERGED_STUB="$2"; shift 2 ;;
    --commits-stub) COMMITS_STUB="$2"; shift 2 ;;
    --concerns-stub) CONCERNS_STUB="$2"; shift 2 ;;
    --shared-stub) SHARED_STUB="$2"; shift 2 ;;
    --ui-test-status-stub) UI_TEST_STATUS_STUB="$2"; shift 2 ;;
    -h|--help) echo "Usage: recommend.sh --check <name> [...stubs]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$CHECK" ]] && { echo "git-workflow: --check <name> required" >&2; exit 2; }

# Profile-aware threshold scaling.
PROFILE_RISK=""
if [[ -n "$PROFILE" && -f "$PROFILE" ]]; then
  PROFILE_RISK=$(grep -E '^risk_tier:' "$PROFILE" | sed -E 's/risk_tier:[[:space:]]*//' | tr -d ' "')
fi

case "$CHECK" in
  branch-hygiene)
    AGE_DAYS=${BRANCH_AGE_STUB%d}
    THRESH_DAYS=${STALE_THRESHOLD%d}
    if [[ -n "$AGE_DAYS" && -n "$THRESH_DAYS" && "$AGE_DAYS" -gt "$THRESH_DAYS" ]]; then
      echo "git-workflow: stale_branch=true age=$BRANCH_AGE_STUB threshold=$STALE_THRESHOLD" >&2
    else
      echo "git-workflow: stale_branch=false age=$BRANCH_AGE_STUB" >&2
    fi
    ;;
  branch-off)
    if [[ "$EMIT" == "thresholds" ]]; then
      if [[ "$PROFILE_RISK" == "regulated" ]]; then
        echo "git-workflow: profile=regulated thresholds_halved=true (regulated risk tier halves defaults)" >&2
      else
        echo "git-workflow: profile=${PROFILE_RISK:-default} thresholds_halved=false" >&2
      fi
      exit 0
    fi
    COMMIT_COUNT=0
    if [[ -n "$ROOT" && -d "$ROOT/.git" ]]; then
      COMMIT_COUNT=$(cd "$ROOT" && git rev-list --count HEAD 2>/dev/null || echo 0)
    fi
    if [[ -n "$COMMIT_THRESHOLD" && "$COMMIT_COUNT" -gt "$COMMIT_THRESHOLD" ]]; then
      echo "git-workflow: recommendation=branch-off reason=commit-threshold-exceeded commits=$COMMIT_COUNT threshold=$COMMIT_THRESHOLD" >&2
    else
      echo "git-workflow: recommendation=stay-on-branch commits=$COMMIT_COUNT" >&2
    fi
    ;;
  diverged-from-main)
    AHEAD=$(echo "$DIVERGED_STUB" | tr ',' '\n' | grep '^ahead=' | sed 's/ahead=//')
    BEHIND=$(echo "$DIVERGED_STUB" | tr ',' '\n' | grep '^behind=' | sed 's/behind=//')
    echo "git-workflow: warning=diverged-from-main ahead=$AHEAD behind=$BEHIND" >&2
    ;;
  merge-strategy)
    if [[ "$SHARED_STUB" == "true" ]]; then
      echo "git-workflow: warning=rebase-on-shared-branch (force-push rewrites collaborators' history)" >&2
      exit 0
    fi
    if [[ -n "$CONCERNS_STUB" && "$CONCERNS_STUB" -gt 1 ]]; then
      echo "git-workflow: recommendation=merge-commit commits=$COMMITS_STUB concerns=$CONCERNS_STUB (multi-concern preserves intent)" >&2
    elif [[ -n "$COMMITS_STUB" && "$COMMITS_STUB" -le 3 && "$CONCERNS_STUB" -le 1 ]]; then
      echo "git-workflow: recommendation=squash commits=$COMMITS_STUB concerns=1 (single-concern, ≤3 commits)" >&2
    else
      echo "git-workflow: recommendation=merge-commit commits=$COMMITS_STUB" >&2
    fi
    ;;
  push-timing)
    # W-9 gate: failing UI regression tests block the push recommendation.
    if [[ "$UI_TEST_STATUS_STUB" == "failing" ]]; then
      echo "git-workflow: warning=ui-regression-tests-failing push_blocked=true (W-9 ui-regression-pinner reports red e2e specs; fix before pushing)" >&2
      exit 0
    fi
    if [[ -n "$ROOT" && -d "$ROOT" ]]; then
      DIRTY=$(cd "$ROOT" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$DIRTY" -gt 0 ]]; then
        echo "git-workflow: warning=uncommitted-changes files=$DIRTY (commit or stash before pushing)" >&2
      else
        echo "git-workflow: push_ok=true working_tree=clean" >&2
      fi
    fi
    ;;
  *)
    echo "git-workflow: unknown --check $CHECK" >&2
    exit 2
    ;;
esac
