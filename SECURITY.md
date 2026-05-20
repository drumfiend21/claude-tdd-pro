# Security

This file is the operator-facing security entrypoint for Claude TDD Pro.

## Threat model

See [docs/threat-model.md](docs/threat-model.md) for the full evolving
threat model — adversarial-repo, compromised standards/PR/compliance
source, insider threat, paywalled-attestation integrity. Each entry
includes the mitigating substrate (S-2/S-12/S-13, L-11/L-13/L-19, C-2/C-4,
W-4/W-5, etc.).

## Reporting

Please file vulnerability reports privately via the repository's
security advisory mechanism (`gh security advisory create`). Do not
disclose suspected issues in public issues or PRs until coordinated.

## Hardening surface

- C-4 merkle-chained audit log (tamper-evident per commit)
- §2.7 sectioned advisory locks (no concurrent rule mutation)
- E-11 RuleTester sandbox (community plugin tests cannot escape)
- L-11 anti-poisoning safeguards (PR-corpus learning gate)
- profile resolution rejects untrusted URLs
- secret-scan hook on every commit
