# Golden reference (second archetype): HIPAA medical-clinic booking app

A second, deliberately different scenario proves the Cloud Architect adapts to the
**business profile** rather than emitting a template. Where the marketplace golden
is public, global, and eventually-consistent, this one is **regulated (HIPAA),
strongly-consistent, and partner-integrated** — and the design changes accordingly.
This is real tool output (cite-or-decline); reproduce it with the command at the end.

## The founder words

> "An online appointment booking app for a medical clinic — secure and reliable, for regulated patient data."

Profile: [`standards/golden/healthcare-booking-hipaa-profile.json`](../../standards/golden/healthcare-booking-hipaa-profile.json) ·
Design: [`standards/golden/healthcare-booking-hipaa-requirements.json`](../../standards/golden/healthcare-booking-hipaa-requirements.json)

## How this design differs from the marketplace (same engine, different profile)

| | Marketplace (public/global) | Healthcare (regulated/partner) |
|---|---|---|
| Consistency | `eventual_consistency` | `strong_consistency`, `synchronous_replication` |
| Compliance-driven | — | `audit_logging`, `audit_log_retention`, `mfa` |
| Public-facing surface | CDN, edge caching, CORS, SPA hosting, public REST gateway | (not pulled in — not public) |
| Total cited decisions | 51 | 43 |

The differences are **driver-traceable**: `consistency_need=strong` pulls in
synchronous replication; `compliance_regime=hipaa` pulls in audit logging,
retention, and MFA; `integration_scope=external-partner` (not `public`) means the
public-edge concerns are correctly *omitted*.

## The full cited design — **43 decisions, 16 authorities, every one cited** (`needs_grounding: []`)

### reliability
- **multi_az** — driver `criticality=mission-critical` — justified by `aws-reliability-pillar`
- **automated_failover** — driver `criticality=mission-critical` — justified by `aws-reliability-pillar`
- **health_check** — driver `criticality=mission-critical` — justified by `aws-reliability-pillar`
- **frequent_backup** — driver `data_loss_tolerance=minutes` — justified by `aws-rpo-rto-targets`

### security
- **encryption_at_rest** — driver `data_sensitivity=regulated` — justified by `nist-800-53`
- **encryption_in_transit** — driver `data_sensitivity=regulated` — justified by `nist-800-53`
- **access_control** — driver `data_sensitivity=regulated` — justified by `nist-800-53`
- **audit_logging** — driver `compliance_regime=hipaa` — justified by `nist-800-53`

### performance-efficiency
- **autoscaling** — driver `scale=large` — justified by `aws-well-architected`
- **caching** — driver `scale=large` — justified by `aws-well-architected`

### operational-excellence
- **monitoring** — driver `baseline` — justified by `google-sre-book`
- **centralized_logging** — driver `baseline` — justified by `opentelemetry-docs`
- **distributed_tracing** — driver `criticality_or_event_driven` — justified by `opentelemetry-docs`
- **slo_alerting** — driver `criticality=mission-critical` — justified by `google-sre-book`
- **audit_log_retention** — driver `compliance_regime=hipaa` — justified by `nist-800-53`
- **access_logging** — driver `data_sensitivity=regulated` — justified by `nist-800-53`

### testing
- **unit_testing** — driver `baseline` — justified by `fowler-test-pyramid`
- **integration_testing** — driver `baseline` — justified by `fowler-test-pyramid`
- **contract_testing** — driver `services_integrate` — justified by `enterprise-integration-patterns`

### dependencies
- **dependency_pinning** — driver `baseline` — justified by `semver`
- **automated_dependency_updates** — driver `baseline` — justified by `google-eng-practices`
- **compatibility_testing** — driver `baseline` — justified by `semver`

### identity
- **authentication** — driver `sensitive_or_exposed` — justified by `oauth2-oidc`
- **authorization_rbac** — driver `data_sensitivity=regulated` — justified by `owasp-asvs`
- **mfa** — driver `regulated_or_compliance` — justified by `nist-800-53`

### storage
- **object_storage_encryption** — driver `data_at_rest` — justified by `nist-800-53`
- **public_access_block** — driver `data_at_rest` — justified by `nist-800-53`
- **bucket_versioning** — driver `data_volume=large` — justified by `aws-well-architected`
- **lifecycle_policy** — driver `data_volume=large` — justified by `aws-well-architected`

### api
- **api_versioning** — driver `integration_scope=external-partner` — justified by `microsoft-rest-api-guidelines`

### realtime
- **websocket_gateway** — driver `data_cadence=real-time` — justified by `enterprise-integration-patterns`
- **connection_auth** — driver `data_cadence=real-time` — justified by `oauth2-oidc`

### data
- **strong_consistency** — driver `consistency_need=strong` — justified by `patterns-of-distributed-systems`
- **synchronous_replication** — driver `consistency_need=strong` — justified by `patterns-of-distributed-systems`
- **partitioning** — driver `data_volume=large` — justified by `azure-data-store-models`
- **sharding** — driver `data_volume=large` — justified by `azure-data-store-models`

### integration
- **message_queue** — driver `communication_style=event-driven` — justified by `enterprise-integration-patterns`
- **dead_letter_queue** — driver `communication_style=event-driven` — justified by `enterprise-integration-patterns`
- **outbox_pattern** — driver `communication_style=event-driven` — justified by `enterprise-integration-patterns`
- **anti_corruption_layer** — driver `integration_scope=external-partner` — justified by `enterprise-integration-patterns`
- **contract_test** — driver `integration_scope=external-partner` — justified by `enterprise-integration-patterns`

### distributed
- **saga** — driver `event-driven+mission-critical` — justified by `fowler-event-sourcing`
- **event_sourcing** — driver `event-driven+mission-critical` — justified by `fowler-event-sourcing`

## Reproduce it yourself

```bash
export CLAUDE_PLUGIN_ROOT="$PWD"
bash commands/business-translate.sh \
  --profile standards/golden/healthcare-booking-hipaa-profile.json \
  --out /tmp/healthcare-design.json --now 2026-06-08T00:00:00Z
# byte-identical to standards/golden/healthcare-booking-hipaa-requirements.json
```
