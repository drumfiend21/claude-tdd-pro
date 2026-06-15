# 🐕 End-to-end walkthrough: a non-technical founder builds a dog-walker marketplace

**This is the fastest way to understand what claude-tdd-pro does.** A founder who
cannot define "multi-AZ" describes an app in plain English. The plugin interviews
them, explains every technical term in business language, and produces a **complete,
world-class, fully-cited** full-stack + cloud architecture — then a red→green build plan.

> **Everything below is real tool output.** Re-create every file in [`artifacts/`](artifacts/)
> deterministically with:
> ```bash
> bash examples/dog-walker-marketplace/regenerate.sh
> ```
> Pipeline: `architect-session` → `business-translate` → `architect-recommend` →
> `optimize-options` → `decision-package` → `cloud-adr`. The integration suite
> (`evals/specs/cl473-e2e-08/09`, `cl474-demo-*`) pins this flow.

| # | Artifact | What it is |
|---|---|---|
| 01 | [`business-profile.json`](artifacts/01-business-profile.json) | the founder's answers |
| 02 | [`technical-requirements.json`](artifacts/02-technical-requirements.json) | **51 cited concerns** across 15 layers |
| 03 | [`architecture-options.json`](artifacts/03-architecture-options.json) | 4 options with honest trade-offs |
| 04 | [`option-scoring.json`](artifacts/04-option-scoring.json) | options scored on 4 business objectives |
| 05 | [`explanation.md`](artifacts/05-explanation.md) | every term in plain business language |
| 06 | [`session.md`](artifacts/06-session.md) | the founder-facing summary |
| 07 | [`decision-package.json`](artifacts/07-decision-package.json) · [`07b-decision-summary.md`](artifacts/07b-decision-summary.md) | the closed loop → 18 build requirements |
| 08 | [`08-adr/0001-…md`](artifacts/08-adr/) | the MADR Architecture Decision Record |

---

## Part 1 — The plugin interviews the founder

The plugin asks 15 plain-English questions. Each answer **drives** later technical
decisions; the `[source]` is the authority the *question itself* is grounded in.

| The plugin asks | The founder answers | Captured as |
|---|---|---|
| What is the workload and what outcome must it deliver? `[azure-waf-business-requirements]` | "Connect dog owners with trusted local walkers; I earn a booking fee." | `workload` |
| Why is this needed — the primary business driver? | "Revenue." | `motivation=revenue` |
| How critical is this to the business? `[aws-rpo-rto-targets]` | "If it's down, walkers miss jobs — mission-critical." | `criticality=mission-critical` |
| How long can it be down before harm? (RTO) | "Only minutes." | `availability_tolerance=minutes` |
| How much recent data could you lose? (RPO) | "A few minutes at most." | `data_loss_tolerance=minutes` |
| How sensitive is the data? `[nist-800-53]` | "Names, addresses, payment info — confidential." | `data_sensitivity=confidential` |
| Which compliance regime applies? | "None yet — a processor handles cards." | `compliance_regime=none` |
| What scale do you expect? `[aws-wa-tool-profiles]` | "Citywide, growing fast — large." | `scale=large` |
| Cost vs uptime posture? | "Balanced." | `budget_posture=balanced` |
| How much data, how fast growing? `[aws-data-analytics-lens]` | "Large — bookings, messages, GPS tracks." | `data_volume=large` |
| Mostly reading, writing, balanced, analytics? | "Balanced." | `read_write_pattern=balanced` |
| Must every read see the latest write? `[patterns-of-distributed-systems]` | "A short lag is fine." | `consistency_need=eventual` |
| Real-time request/response, or events/queues? `[enterprise-integration-patterns]` | "A booking triggers notifications, payment, matching — events." | `communication_style=event-driven` |
| Who does it integrate with? | "The public — anyone can sign up." | `integration_scope=public` |
| Real-time, near-real-time, or batch data? | "Real-time — owners watch the walk live." | `data_cadence=real-time` |

→ [`artifacts/01-business-profile.json`](artifacts/01-business-profile.json)

> **Cite-or-decline:** if the founder asks about a term the plugin can't ground, it
> refuses to bluff and opens a clarification loop:
> *"I don't recognise 'message_queue'. In plain terms, what should it do for your
> users or business?"* — then maps the answer to a grounded concern before deciding.

## Part 2 — The plugin explains the technical terms (so the founder can decide)

Verbatim from [`artifacts/05-explanation.md`](artifacts/05-explanation.md) — every line cited:

| Term | What it means for you | Why it matters | Source |
|---|---|---|---|
| **encryption_at_rest** | scramble stored data so it's unreadable if storage is stolen | protects customer data & meets compliance obligations | nist-800-53 |
| **encryption_in_transit** | scramble data while it travels between systems | stops anyone in the middle reading sensitive info | nist-800-53 |
| **multi_az** | run copies in separate data centers in the same region | one data-center outage won't take your service down | aws-reliability-pillar |
| **automated_failover** | automatically switch to a healthy backup when the primary fails | customers stay served without waiting for a human | aws-reliability-pillar |
| **autoscaling** | add/remove capacity automatically as demand changes | stays fast under load; you only pay for what you use | aws-well-architected |
| **caching** | keep frequently used data close by for quick reuse | faster responses for customers and lower cost | aws-well-architected |
| **access_control** | decide who is allowed to do what in the system | keeps the wrong people away from sensitive data | nist-800-53 |

## Part 3 — The plugin makes the technical decisions

### 3a. Answers → cited technical concerns

51 concerns across 15 layers, **`needs_grounding = 0`** (every decision cited). Each
shows the `answer that drove it` → `[authority]`. Full file:
[`artifacts/02-technical-requirements.json`](artifacts/02-technical-requirements.json).

- **Reliability** ← *mission-critical + minutes RTO + public-at-scale*: `multi_az`, `automated_failover`, `health_check`, `frequent_backup`, `multi_region`, `latency_based_routing` `[aws-reliability-pillar, aws-rpo-rto-targets]`
- **Security** ← *confidential data*: `encryption_at_rest`, `encryption_in_transit`, `access_control` `[nist-800-53]`
- **Performance** ← *large scale + public*: `autoscaling`, `caching`, `cdn`, `edge_caching` `[aws-well-architected]`
- **Integration / Distributed** ← *event-driven + mission-critical*: `message_queue`, `dead_letter_queue`, `outbox_pattern` `[enterprise-integration-patterns]`, `saga`, `event_sourcing` `[fowler-event-sourcing]`
- **Realtime** ← *live tracking*: `websocket_gateway` `[enterprise-integration-patterns]`, `connection_auth` `[oauth2-oidc]`
- **API / Edge / Frontend** ← *public*: `rest_api_gateway`, `rate_limiting`, `request_validation`, `api_versioning` `[microsoft-rest-api-guidelines]`, `security_headers`, `cors_policy` `[owasp-secure-headers]`, `spa_hosting`, `http_compression` `[aws-well-architected]`
- **Identity** `authentication` `[oauth2-oidc]`, `authorization_rbac`/`token_validation` `[owasp-asvs]` · **Data** `eventual_consistency` `[patterns-of-distributed-systems]`, `partitioning`/`sharding` `[azure-data-store-models]` · **Operational** `slo_alerting` `[google-sre-book]`, `distributed_tracing` `[opentelemetry-docs]` · **Testing** `unit/integration/contract_testing` `[fowler-test-pyramid]`

### 3b. A choice, with honest trade-offs

From [`artifacts/03-architecture-options.json`](artifacts/03-architecture-options.json):

| Option | Cost | Availability | Complexity | Lock-in |
|---|---|---|---|---|
| Cost-optimized baseline | low | medium | low | medium |
| **▶ Balanced hybrid** *(recommended)* | medium | **high** | medium | **low** |
| Resilient scale-out | high | high | high | medium |
| Max-resilience multi-region | high | very-high | high | medium |

### 3c. Scored against the founder's objectives → recommended

[`artifacts/04-option-scoring.json`](artifacts/04-option-scoring.json) ranks on
cost / performance / customer / shareholder value (weighted by the profile):

**`opt-balanced > opt-max > opt-cost > opt-resilient`** → **Balanced hybrid** — high
availability + low vendor lock-in at medium cost, the best fit for a *balanced,
mission-critical, growing* business.

### 3d. The loop closes → an enforceable build plan

[`artifacts/07-decision-package.json`](artifacts/07-decision-package.json):
`loop_closed = true`, chosen `opt-balanced`, **18 build requirements**
(`encryption_at_rest`, `multi_az`, `cdn`, …), and a MADR
[ADR](artifacts/08-adr/) recording the decision (grounded, status `accepted`).

Those 18 requirements become **test-first IaC build units** (`cloud-build`): each
starts `conformance=red` until the infrastructure satisfies it, then turns green —
and is checked against the EO `eo-security.yaml` conventions (provenance,
digest-pinned images, no `0.0.0.0/0`).

---

**The whole arc:** plain-English vision → 15 questions → every term explained →
a 51-decision, fully-cited, world-class architecture → an honest recommendation →
a red→green build plan. Tailored to *this* marketplace (event-driven, real-time,
public) and nothing it doesn't need. For a contrasting example, the same pipeline
produces just **17 concerns** for a simple low-budget newsletter site — it never
over-engineers.
