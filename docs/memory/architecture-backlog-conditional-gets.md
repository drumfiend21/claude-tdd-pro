---
name: Architecture backlog — conditional GETs for registry fetchers
description: Design note for next Claude TDD Pro version — implement HTTP conditional GET (If-None-Match / If-Modified-Since) across S-2, L-2, and the compliance fetcher so daily-or-more-frequent polling is nearly free for stable upstream sources.
type: project
originSessionId: 6d636ecc-f923-462a-943c-a116be00d582
---
Add HTTP conditional GET support to the fetcher pipelines for all three operator-curated registries (STANDARDS-URLS.yaml, PR-SOURCES.yaml, COMPLIANCE-URLS.yaml).

**Why:** Current `fetch_frequency` field defaults to weekly/monthly for many sources because daily full-body fetch is wasteful for stable resources (Google style guides, NIST PDFs, frozen regulations). Conditional GET (RFC 7232) lets the fetcher ask "did this change since I last saw it?" via `If-None-Match: <etag>` or `If-Modified-Since: <timestamp>`. Server returns `304 Not Modified` for unchanged content — no body, no parse, no diff. Daily polling becomes nearly free for stable sources, freeing up the architecture to default everything to `daily` (or finer per the in-use polling note) without bandwidth, token-budget, or rate-limit concerns.

**How to apply:**
- Extend each fetcher (S-2, L-2 for GitHub API endpoints, new compliance fetcher) to:
  - Persist `etag` and `last-modified` headers from each successful 200 response, alongside content_hash
  - Send `If-None-Match` and `If-Modified-Since` on subsequent fetches
  - On 304: update `.claude-tdd-pro/<registry>-last-fetch/<id>.timestamp` (proves freshness check happened) but skip downstream pipeline (parse, diff, hash compare)
  - On 200: full pipeline as today
- GitHub API supports conditional requests on issues/comments/pulls endpoints — applies cleanly to L-2
- For paywalled sources (HEAD-only): conditional GET is moot (HEAD already cheap); preserve current behavior
- Cost telemetry (H-1) records per-source 304-vs-200 ratio so operator can see how cheap the daily-fetch posture actually is in their environment
- Pairs with the in-use polling backlog note (architecture-backlog-in-use-polling.md): conditional GETs are the prerequisite that makes high-frequency in-use polling cost-defensible

This goes into the next architectural iteration (v1.8 candidate), not v1.7. Pre-requisite for collapsing `fetch_frequency` to a hint rather than a polling cost gate.
