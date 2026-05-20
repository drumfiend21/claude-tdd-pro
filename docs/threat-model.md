# Threat model — Claude TDD Pro

## Version history

| Revision | Date | Change |
|---|---|---|
| 0.1 | 2026-05-20 | Initial draft per O-8 (Week 20). |

This document evolves with each major architectural change. See SECURITY.md
for the operator-facing entry point and the reference page (docs/reference.md)
for cross-links to other security docs.

## adversarial-repo

A repository deliberately crafted to subvert the rule engine — fixtures
that look benign but match malicious patterns, profile YAML that points
at a hostile standards URL, or test cases that flip rule severity at
parse time. Mitigations: profile resolution rejects untrusted URLs;
G-12 source-file validator enforces a strict schema; E-11 RuleTester
runs sandboxed; pre-commit hook runs in a clean shell.

## compromised-standards-source

An upstream standards source (e.g. owasp-asvs.json hosted at a
maintainer-owned URL) ships a malicious or accidentally-bad revision.
Mitigations: S-2 fetcher uses content_hash pinning per STANDARDS-URLS.yaml;
S-12 freshness gate refuses generation past fragility-tier window;
audit-pack records standards_state with `fetched_at`, `content_hash`,
`freshness_at_generation`; S-13 operator-curation lets an operator pin
to a known-good revision.

## compromised-PR-source

An upstream PR source (e.g. cfpb-consumerfinance) is hijacked to
plant a poisoned pattern (self-approval, single-org cabal, rapid merge).
Mitigations: L-11 anti-poisoning safeguards.sh blocks self-approval +
single-org-cabal + rapid-merge patterns before extraction; L-13
conflict surfacing requires operator resolution before promotion;
L-19 daily-fresh gate refuses to learn from a stale source; pr-corpus
provenance entries cite every supporting PR with verbatim_quote.

## compromised-compliance-source

A compliance framework source (e.g. SOC2 control catalog) is hijacked
to weaken a control mapping. Mitigations: C-2 fetcher pins
content_hash; C-3 mapping requires verbatim_quote citation; audit-pack
emits compliance_state with `legal_review_status`; H-10 community
contributions require 2-reviewer approval for tier 1.

## insider-threat

An operator with commit access ships a profile that bypasses the
freshness gate, mutes critical rules, or back-dates an attestation.
Mitigations: C-4 merkle-chained audit log per commit (tamper-evident);
provenance trail includes commit SHA; W-4 decision-trail ADR required
for severity overrides; --strict mode refuses runs with mute-without-
justification.

## paywalled-attestation integrity

An attestation document (e.g. a SOC2 audit report) sits behind a
paywall — the operator can claim coverage without the auditor's
authoritative artifact being verifiable by the audit-pack consumer.
Mitigations: license_expiry field on attestations; audit-pack
'Attestations' section reports expired/active; W-5 decision-trail
records the consultation; C-19 enforces refresh on framework edition
change.
