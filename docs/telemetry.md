# Telemetry — what the plugin shares, and how to turn it off

The plugin (`claude-tdd-pro` / the GCTP harness that consumes it) includes one
disclosed, on-by-default telemetry feature: **public source-URL reporting**. This
document is the full disclosure. If you read nothing else: only *public* standards
URLs are shared, and you can turn it off in one step.

## What is shared

When you register a rules-source URL (in a registry file or your `ctp.config.yaml`
`sources:` block) and a refresh runs, the plugin reports that source URL to the
plugin author. The purpose is fleet-level insight: which authoritative standards
sources produce world-class software, so the shared standards corpus keeps
improving.

Each report contains only:

| Field | Example | Notes |
|---|---|---|
| `url` | `https://owasp.org/www-project-top-ten/` | `scheme://host/path` only — **query and fragment stripped** |
| `event` | `source-url-registered` | fixed |
| `anon_install_id` | a random UUID | generated once, lets the author count distinct installs without identifying you |
| `plugin_version` | e.g. `1.27` | |

## What is NEVER shared

- **Non-public sources.** A URL is reported only if its host resolves to a
  globally-routable public address. These are **ignored entirely — never
  transmitted, never logged**:
  - RFC1918 / loopback / link-local IPs (`10.*`, `172.16–31.*`, `192.168.*`, `127.*`, …)
  - Reserved TLDs (`.internal`, `.local`, `.localhost`, `.test`, `.example`,
    `.invalid`, `.home.arpa`, `.corp`, `.lan`, `.intranet`)
  - Single-label intranet hostnames (no dot)
  - `file://` and any non-`http(s)` scheme
  - Any host that resolves to a private address, or does not resolve at all
    (internal-only DNS)
- **Query strings and fragments** — stripped even from public URLs, so tokens,
  API keys, and session identifiers never leave your machine.
- **Repo content, rule text, file paths, usernames, org names** — none of it.

This scoping is deliberate: it protects your and others' proprietary property,
keeps the plugin license-clean and commercially distributable, and keeps the
reported data outside GDPR "personal data" (a public standards URL is a fact).

## No GitHub noise

Telemetry is a quiet HTTPS POST to the author's collector. It **never** opens an
issue, pull request, comment, or notification on any repository — yours or the
author's. You will see a single one-line notice on stderr each time a public URL
is actually shared, and nothing when nothing is shared.

## How to turn it off

Any one of these disables all sharing (they are checked before anything is sent):

- Environment: `CTP_TELEMETRY=off`
- Environment: `DO_NOT_TRACK=1` (the cross-tool [Console Do Not Track](https://consoledonottrack.com) standard)
- Config: `telemetry: off` in your `ctp.config.yaml`

When opted out, the plugin sends nothing and prints nothing about telemetry.

## Fails open

If the author's endpoint is unreachable — a restricted network, an offline
session, no configured endpoint — nothing is sent and your work proceeds
normally. Telemetry never blocks, delays, or fails a refresh.

## For the plugin author / self-hosters

The collector endpoint is set with `CTP_TELEMETRY_ENDPOINT` (an HTTPS URL that
accepts a JSON POST body). With no endpoint configured, reports are written only
to a local outbox (if `--outbox` is passed) and nothing leaves the machine. The
sender is `commands/source-url-telemetry.sh`; the transport can be replaced for
testing via `CTP_TELEMETRY_TRANSPORT`.
