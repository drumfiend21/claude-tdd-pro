---
name: Architecture backlog — in-use polling frequency
description: Design note for next Claude TDD Pro version — add an in-use millisecond polling option to fetch_frequency for all three operator-curated registries (STANDARDS-URLS, PR-SOURCES, COMPLIANCE-URLS).
type: project
originSessionId: 6d636ecc-f923-462a-943c-a116be00d582
---
Add a new `fetch_frequency` mode: **"once every X milliseconds while the plugin is in use"** — applicable across all three operator-curated registries (STANDARDS-URLS.yaml, PR-SOURCES.yaml, COMPLIANCE-URLS.yaml).

**Why:** Current `fetch_frequency` field only supports cron-style intervals (`daily`, `weekly`, `monthly`, `quarterly`). Operator wants finer-grained, in-session polling — fetches happen on a wall-clock interval *while the plugin is actively in use*, not on a calendar cadence. Useful when actively iterating against rapidly-changing upstream guidance (e.g., during a major regulatory update period, or while watching react.dev RFC pages during a framework upgrade).

**How to apply:**
- Extend `fetch_frequency` in §2.6 (standards source contract), §2.12 (PR source contract), §2.19 (compliance source contract) to accept either:
  - Calendar-style strings: `daily`, `weekly`, `monthly`, `quarterly`, `on-demand` (existing behavior)
  - Millisecond intervals: `<N>ms` or `<N>s` or `<N>m` (e.g., `300000ms`, `30s`, `5m`) — fetcher runs that often *only while a Claude Code session is active*
  - Or `any-frequency` shorthand mapping to a config-file default
- Configurable defaults in a top-level `.claude-tdd-pro/FETCH-FREQUENCIES.yaml` operator-editable file mapping per-registry-default and per-source-override frequencies
- Pair with conditional GETs (Tier 1 recommendation already noted) so high-frequency in-use polling stays cheap when content is stable
- In-use detection: piggyback on existing active-flow stack (§2.13) presence as proxy for "plugin in use"
- Honor in /doctor (display next-fetch-eta per source) and in cost telemetry (H-1)

This goes into the next architectural iteration (v1.8 candidate), not v1.7.
