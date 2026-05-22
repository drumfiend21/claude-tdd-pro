#!/usr/bin/env bash
# C-6 PII/secrets egress guard. Scans an input file for SSN, IBAN,
# BIC/SWIFT, credit-card (Luhn-validated), passport, EU national ID,
# US driver's license, and high-entropy API-key patterns. Exits 0 if
# clean, 2 if a sensitive pattern is detected. The detected category
# is named on stderr (e.g., "ssn", "iban", "credit", "bic",
# "passport", "national-id", "driver", "api").
set -uo pipefail
INPUT=""
CHECK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -h|--help) echo "Usage: pii-egress-guard.sh --input <file> --check" >&2; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$INPUT" || ! -f "$INPUT" ]] && { echo "pii-egress-guard: --input <file> required" >&2; exit 2; }
[[ "$CHECK" -ne 1 ]] && { echo "pii-egress-guard: --check required" >&2; exit 2; }

INPUT="$INPUT" node -e '
  const fs = require("fs");
  const text = fs.readFileSync(process.env.INPUT, "utf8");

  function luhn(s) {
    const digits = s.replace(/\D/g, "");
    if (digits.length < 13 || digits.length > 19) return false;
    let sum = 0;
    let alt = false;
    for (let i = digits.length - 1; i >= 0; i--) {
      let n = parseInt(digits[i], 10);
      if (alt) { n *= 2; if (n > 9) n -= 9; }
      sum += n;
      alt = !alt;
    }
    return sum % 10 === 0;
  }

  // Order matters: more specific patterns first.
  // SSN
  if (/(?:^|[^0-9])\d{3}-\d{2}-\d{4}(?:[^0-9]|$)/.test(text)) {
    process.stderr.write("pii-egress-guard: blocked category=ssn pattern=us-social-security-number\n");
    process.exit(2);
  }
  // IBAN: 2 letters + 2 digits + 11-30 alnum (must contain at least one digit)
  {
    const m = text.match(/\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/);
    if (m) {
      process.stderr.write(`pii-egress-guard: blocked category=iban pattern=${m[0].slice(0, 6)}...\n`);
      process.exit(2);
    }
  }
  // BIC/SWIFT: 4 letters (bank) + 2 letters (country) + 2 alnum (location) + optional 3 alnum (branch)
  {
    const m = text.match(/\b[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\b/);
    if (m && m[0].length === 8 || (m && m[0].length === 11)) {
      process.stderr.write(`pii-egress-guard: blocked category=bic pattern=${m[0]}\n`);
      process.exit(2);
    }
  }
  // Credit card with Luhn
  {
    const re = /\b(?:\d[ -]?){13,19}\b/g;
    let m;
    while ((m = re.exec(text)) !== null) {
      const candidate = m[0];
      if (luhn(candidate)) {
        process.stderr.write(`pii-egress-guard: blocked category=credit pattern=credit-card-luhn-valid\n`);
        process.exit(2);
      }
    }
  }
  // EU national ID — Spain DNI: 8 digits + letter; cued by "DNI" or "NIE"
  if (/\b(?:DNI|NIE|CIF)\s*\d{7,8}-?[A-Z]\b/.test(text)) {
    process.stderr.write("pii-egress-guard: blocked category=national-id pattern=eu-national-id\n");
    process.exit(2);
  }
  // Passport: cued by "passport"
  if (/passport\s*:?\s*[A-Z]\d{6,9}\b/i.test(text)) {
    process.stderr.write("pii-egress-guard: blocked category=passport pattern=passport-number\n");
    process.exit(2);
  }
  // US driver license: cued by "DL"
  if (/\bDL\s*:?\s*[A-Z]\d{6,8}\b/i.test(text) || /\bdriver(?:\W?s)?\W*license\s*:?\s*[A-Z]\d{6,8}\b/i.test(text)) {
    process.stderr.write("pii-egress-guard: blocked category=driver pattern=us-drivers-license\n");
    process.exit(2);
  }
  // API key: high-entropy >= 40 chars, alnum + dashes/underscores
  {
    const m = text.match(/\b(?:sk|pk|ghp|gho|github_pat|xox[abprs]|AIza|AKIA)[A-Za-z0-9_-]{20,}\b/);
    if (m) {
      process.stderr.write(`pii-egress-guard: blocked category=api pattern=api-key-prefix-match\n`);
      process.exit(2);
    }
    const m2 = text.match(/\b[A-Za-z0-9_-]{40,}\b/);
    if (m2) {
      // Entropy heuristic: must contain at least one letter, one digit, one dash/underscore OR mixed case.
      const s = m2[0];
      const hasUpper = /[A-Z]/.test(s);
      const hasLower = /[a-z]/.test(s);
      const hasDigit = /\d/.test(s);
      const hasSep = /[-_]/.test(s);
      const variety = [hasUpper, hasLower, hasDigit, hasSep].filter(Boolean).length;
      if (variety >= 3) {
        process.stderr.write(`pii-egress-guard: blocked category=api pattern=high-entropy-token\n`);
        process.exit(2);
      }
    }
  }

  process.stderr.write("pii-egress-guard: ok no_pii_or_secrets_detected\n");
'
