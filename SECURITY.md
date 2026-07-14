# Security

This file is the operator-facing security entrypoint for Claude TDD Pro.
The full evolving threat model lives at [docs/threat-model.md](docs/threat-model.md).

## Threat model

See [docs/threat-model.md](docs/threat-model.md) for the full evolving
threat model. The sections below summarize the per-area trust posture
and mitigation pointers. Each entry includes the mitigating substrate
(S-2/S-12/S-13, L-11/L-13/L-19, C-2/C-4, W-4/W-5, etc.).

## Trust boundary

Claude TDD Pro runs entirely on the operator's machine and treats every
external input as untrusted. The trust boundary sits at:
- the operator's local filesystem (trusted),
- the active profile + resolved standards source folders (trusted, but
  every input is provenance-stamped per §2.8),
- and everything else (network, registries, paywalled attestations,
  third-party plugins) — untrusted, mediated through the fetcher trust
  models below.

## Hook safety

Per-script hardening of hooks under `hooks/scripts/`:
- Every hook script runs with `set -uo pipefail`.
- Hooks soft-fail on errors so a broken hook never blocks a session
  (e.g. `sync-memory.sh` reports to stderr but exits 0).
- Hooks never `eval` operator-supplied content.
- Hooks scope file writes to `.claude-tdd-pro/` or explicitly-passed
  paths; no traversal outside the project tree.
- The TDD-Guard PreToolUse hook is the only commit-blocking hook in
  the default profile; its bypass surface (`--allow-red-test`) is
  audited to the C-4 merkle-chained log per the W-8 contract.

## Hardening surface

- C-4 merkle-chained audit log (tamper-evident per commit)
- §2.7 sectioned advisory locks (no concurrent rule mutation)
- E-11 RuleTester sandbox (community plugin tests cannot escape)
- L-11 anti-poisoning safeguards (PR-corpus learning gate)
- profile resolution rejects untrusted URLs
- secret-scan hook on every commit

## standards fetcher trust model

The standards fetcher (S-2) treats every upstream URL as untrusted.
Trust posture: pinned source-folder yaml with `authoritative_publisher`
+ `content_hash`; fetch surfaces a stale-warn-degraded state when the
remote hash mismatches; freshness gate per §2.17 blocks promotion of
stale standards into the active rule set.

## PR fetcher trust model

The PR fetcher (L-2) treats every upstream repository as untrusted.
Trust posture: per-source `PR-SOURCES.yaml` registry pins the
`source_class` + `tier`; the L-11 anti-poisoning safeguards reject
self-approved PRs and rapid-merge patterns before they reach pattern
extraction; the L-13 conflict surfacer blocks promotion when an
operator-resolved decision exists.

## compliance fetcher trust model

The compliance fetcher (C-2) treats every framework feed as untrusted.
Trust posture: signed checkpoints (O-5) verify upstream fetch
provenance; the C-7 control-mapping gate refuses promotion when the
mapping fails schema validation.

## audit.log integrity

Per C-4, every workflow transition, promotion event, operator bypass,
and force-remove appends a structured JSONL entry to
`compliance/audit.log`. Entries are merkle-chained so any tamper
attempt invalidates downstream checkpoints. The `compliance/checkpoint.sh`
script emits a sealed `merkle_root` per included-event window.

## paywalled attestation integrity

Compliance frameworks with paywalled attestations (e.g. SOC2 reports
behind vendor portals) are referenced by license-recorded URL rather
than fetched directly. The operator-added trust model: the operator
explicitly records the attestation's license terms via
`compliance/attestations/<framework>.yaml` with `license_expiry`,
which audit-pack flags as expired vs active per H-8 license attribution
sweep. Operator-added attestations enter the trust boundary explicitly,
with the same provenance treatment as a tier-1 published standard.

## signing key handling

Plugin signing (E-7 `require_signed_plugins: true`) verifies signatures
against the configured signing keys in `userConfig.yaml`. Operator
signing keys are stored under `.claude-tdd-pro/keys/` and excluded
from git via `.gitignore`. The plugin self-test CI (H-11) never reads
operator keys — it uses a dedicated CI signing-key path.

## MCP token handling

MCP server tokens (issued by `mcp__*` connectors) are operator-scoped
and never written to disk by the plugin. `/audit-pack` redacts any
header value matching the `Bearer ` prefix when bundling logs. The
session-environment file (`~/.claude/session-env/<id>`) is owned by
the operator's user account and never copied into the project tree.

## PII guard limits

The C-6 PII egress guard refuses to write PII patterns
(emails, SSN-formatted numbers, credit-card-formatted numbers) into
shared logs. Limits: the guard is regex-based, so adversarially-
formatted inputs can still leak. Operators in regulated-tier profiles
should layer a downstream egress filter; the plugin's guard is
defense-in-depth, not a sole boundary.

## SPACE privacy

The Q-phase SPACE measurement collector (Q-2) is solo-scale only.
Configuration: `space/config.yaml` defaults to `share: never`. The
`/space-report` dashboard refuses `--aggregate-users` (no team
roll-up, no benchmarking) and refuses `--share <target>` when config
`share: never`. The retention sweep (Q-7) deletes metrics past the
configured window. **This SPACE productivity data is never uploaded —
it stays on your machine unless you explicitly opt in to share it.**

## Source-URL telemetry (disclosed, public-only)

Separate from the local-only SPACE data above, the plugin reports the
**public** rules-source URLs you register to the plugin author, so the
author can learn which authoritative standards sources produce the best
software across the fleet. This is **on by default and openly disclosed**
(full detail: [`docs/telemetry.md`](docs/telemetry.md)). What it does and
does not do:

- **Only PUBLIC sources are sent.** A URL is reported only if its host
  resolves to a globally-routable address on the public internet. Private
  / internal / unresolvable hosts (RFC1918 IPs, `.internal`/`.local`,
  single-label intranet names, `file://`, anything that resolves to a
  private address or not at all) are **ignored entirely — never
  transmitted, never logged.** This protects your (and others')
  proprietary infrastructure.
- **Only `scheme://host/path` is sent** — query strings and fragments are
  stripped, so tokens/keys never leave your machine. No repo content, no
  rule text, no repo path, no username.
- **No GitHub noise.** It is a quiet HTTPS POST. It never opens an issue,
  PR, comment, or notification on any repository.
- **A one-line notice prints** each time a public URL is actually shared.
- **Opt out any time** with `CTP_TELEMETRY=off`, the cross-tool
  `DO_NOT_TRACK=1` standard, or `telemetry: off` in your `ctp.config.yaml`.
- **Fails open, never blocks you.** If the endpoint is unreachable (e.g.
  a restricted network), nothing is sent and your work is unaffected.

## Reporting

Please file vulnerability reports privately via the repository's
security advisory mechanism (`gh security advisory create`). Do not
disclose suspected issues in public issues or PRs until coordinated.
