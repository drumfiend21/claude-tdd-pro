#!/usr/bin/env bash
# Secret scanner — invoked by the snapshot skill, tdd-driver agent, and
# any commit pathway BEFORE `git add` / `git commit`.
#
# Returns 0 = clean, 2 = secret detected (must surface to user/agent).
# Designed to fail loudly: if anything looks secret-shaped, we refuse.
#
# Two passes:
#   1. Filenames known to hold secrets (.env, credentials, keys).
#   2. Content patterns inside the staged diff (AWS keys, GitHub
#      tokens, OpenAI keys, private keys, generic high-entropy
#      base64/hex strings near "secret"/"key"/"token" identifiers).

set -uo pipefail

cd "${1:-$PWD}" || exit 0

found=0

# ─── Pass 1: dangerous filenames ────────────────────────────────
DANGER_FILES=$(git status --porcelain 2>/dev/null \
  | awk '{print $2}' \
  | grep -E '(^|/)(\.env(\..*)?|\.envrc|\.aws/credentials|\.aws/config|id_[rd]sa|id_ecdsa|id_ed25519|.*\.pem|.*\.p12|.*\.pfx|.*\.keystore|.*\.key|google-credentials\.json|service-account.*\.json|firebase-key.*\.json|.*\.netrc|kubeconfig|.*\.kubeconfig)$' \
  || true)

if [[ -n "$DANGER_FILES" ]]; then
  echo "[secret-scan] REFUSING: secret-bearing filename(s) staged or untracked:" >&2
  echo "$DANGER_FILES" | sed 's/^/  /' >&2
  echo "" >&2
  echo "Add these to .gitignore (and rotate if previously committed):" >&2
  echo "$DANGER_FILES" | awk '{print "  echo \"" $1 "\" >> .gitignore"}' >&2
  found=1
fi

# ─── Pass 2: secret-shaped content in staged diff ───────────────
# Only scan the staged diff (what's about to be committed), not the
# whole tree, to avoid false positives in vendored fixtures.
DIFF=$(git diff --cached -U0 2>/dev/null || true)

# Patterns: high-confidence prefixes used by major providers.
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                             # AWS Access Key
  'ASIA[0-9A-Z]{16}'                             # AWS STS
  'aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{40}'
  'ghp_[A-Za-z0-9]{36}'                          # GitHub PAT
  'github_pat_[A-Za-z0-9_]{82}'                  # GitHub fine-grained
  'gho_[A-Za-z0-9]{36}'                          # GitHub OAuth
  'sk-[A-Za-z0-9_-]{20,}'                        # OpenAI / Anthropic
  'xox[baprs]-[A-Za-z0-9-]{10,}'                 # Slack tokens
  'AIza[A-Za-z0-9_-]{35}'                        # Google API key
  'glpat-[A-Za-z0-9_-]{20}'                      # GitLab PAT
  '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'        # any PEM private key
  'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'  # JWT
)

for pat in "${PATTERNS[@]}"; do
  # Use -e so patterns that start with '-' aren't read as options.
  # Drop -H (filename header) since we read from stdin.
  HITS=$(printf '%s' "$DIFF" | grep -En -e "$pat" 2>/dev/null || true)
  if [[ -n "$HITS" ]]; then
    echo "[secret-scan] REFUSING: secret-shaped string in staged diff (pattern: $pat)" >&2
    echo "$HITS" | head -5 | sed 's/^/  /' >&2
    found=1
  fi
done

if [[ $found -eq 1 ]]; then
  echo "" >&2
  echo "If these are intentional (test fixtures, etc), either:" >&2
  echo "  1. Move them to a non-staged path; or" >&2
  echo "  2. Add an inline comment containing 'secret-scan: ignore' on the same line; or" >&2
  echo "  3. Skip the hook with --no-verify (NOT recommended)." >&2
  exit 2
fi

exit 0
