#!/usr/bin/env bash
# /compliance-attest — C-15 paywalled-attestation skill backbone.
# Records license_holder + license_expiry for paywalled compliance
# frameworks. Refuses past expiry dates. --revoke archives.
#
# Usage:
#   compliance-attest.sh --framework <id> --license-holder <name>
#                         --license-expiry <YYYY-MM-DD> [--now <iso>]
#   compliance-attest.sh --revoke <framework-id>

set -uo pipefail

FRAMEWORK=""; HOLDER=""; EXPIRY=""; NOW_ISO=""; REVOKE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --license-holder) HOLDER="$2"; shift 2 ;;
    --license-expiry) EXPIRY="$2"; shift 2 ;;
    --now) NOW_ISO="$2"; shift 2 ;;
    --revoke) REVOKE="$2"; shift 2 ;;
    *) echo "compliance-attest: unknown flag: $1" >&2; exit 2 ;;
  esac
done

mkdir -p compliance/attestations

if [[ -n "$REVOKE" ]]; then
  TARGET="compliance/attestations/$REVOKE.yaml"
  [[ ! -f "$TARGET" ]] && { echo "compliance-attest: no attestation for $REVOKE" >&2; exit 1; }
  mkdir -p compliance/attestations/_archived
  mv "$TARGET" compliance/attestations/_archived/
  echo "compliance-attest: revoked $REVOKE (archived)" >&2
  exit 0
fi

[[ -z "$FRAMEWORK" || -z "$HOLDER" || -z "$EXPIRY" ]] && {
  echo "compliance-attest: --framework, --license-holder, --license-expiry required" >&2; exit 2; }

[[ -z "$NOW_ISO" ]] && NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_DATE=$(echo "$NOW_ISO" | cut -dT -f1)
if [[ "$EXPIRY" < "$NOW_DATE" ]]; then
  echo "compliance-attest: license_expiry $EXPIRY is in the past (now=$NOW_DATE); attestation requires non-past expiry" >&2
  exit 2
fi

cat > "compliance/attestations/$FRAMEWORK.yaml" <<YAML
framework: $FRAMEWORK
license_holder: $HOLDER
license_expiry: $EXPIRY
attested_at: $NOW_ISO
YAML
echo "compliance-attest: recorded attestation for $FRAMEWORK" >&2
