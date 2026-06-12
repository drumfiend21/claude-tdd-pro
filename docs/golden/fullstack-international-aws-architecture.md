# Golden Reference: World-Class Full-Stack Cloud Architecture (AWS, international)

The canonical output the cloud-architect feature must conform to. A non-technical founder vision -> a fully-cited, world-class full-stack + cloud architecture. Every decision is justified by a cited source (cite-or-decline). Regenerate with `commands/business-translate.sh --profile standards/golden/fullstack-international-aws-profile.json`.

## Frontend / UI

- **spa_hosting** - justified by `aws-well-architected` (driver: public_facing_ui)
- **http_compression** - justified by `aws-well-architected` (driver: ui_responsiveness)

## Backend API

- **rest_api_gateway** - justified by `microsoft-rest-api-guidelines` (driver: request_response_or_public)
- **rate_limiting** - justified by `microsoft-rest-api-guidelines` (driver: integration_scope=public)
- **request_validation** - justified by `microsoft-rest-api-guidelines` (driver: integration_scope=public)
- **api_versioning** - justified by `microsoft-rest-api-guidelines` (driver: integration_scope=public)

## Database

- **eventual_consistency** - justified by `patterns-of-distributed-systems` (driver: consistency_need=eventual)
- **partitioning** - justified by `azure-data-store-models` (driver: data_volume=large)
- **sharding** - justified by `azure-data-store-models` (driver: data_volume=large)

## Messaging & Integration

- **message_queue** - justified by `enterprise-integration-patterns` (driver: communication_style=event-driven)
- **dead_letter_queue** - justified by `enterprise-integration-patterns` (driver: communication_style=event-driven)
- **outbox_pattern** - justified by `enterprise-integration-patterns` (driver: communication_style=event-driven)
- **anti_corruption_layer** - justified by `enterprise-integration-patterns` (driver: integration_scope=public)
- **contract_test** - justified by `enterprise-integration-patterns` (driver: integration_scope=public)

## Real-time

- **websocket_gateway** - justified by `enterprise-integration-patterns` (driver: data_cadence=real-time)
- **connection_auth** - justified by `oauth2-oidc` (driver: data_cadence=real-time)

## Authentication & Authorization

- **authentication** - justified by `oauth2-oidc` (driver: sensitive_or_exposed)
- **authorization_rbac** - justified by `owasp-asvs` (driver: data_sensitivity=confidential)
- **token_validation** - justified by `owasp-asvs` (driver: integration_scope=public)

## Object Storage

- **object_storage_encryption** - justified by `nist-800-53` (driver: data_at_rest)
- **public_access_block** - justified by `nist-800-53` (driver: data_at_rest)
- **bucket_versioning** - justified by `aws-well-architected` (driver: data_volume=large)
- **lifecycle_policy** - justified by `aws-well-architected` (driver: data_volume=large)

## Edge / HTTP Headers

- **security_headers** - justified by `owasp-secure-headers` (driver: integration_scope=public)
- **cors_policy** - justified by `owasp-secure-headers` (driver: integration_scope=public)

## Performance

- **autoscaling** - justified by `aws-well-architected` (driver: scale=hyperscale)
- **caching** - justified by `aws-well-architected` (driver: scale=hyperscale)
- **cdn** - justified by `aws-well-architected` (driver: public_facing_fast_requests)
- **edge_caching** - justified by `aws-well-architected` (driver: public_facing_fast_requests)

## Reliability & Global Delivery

- **multi_az** - justified by `aws-reliability-pillar` (driver: criticality=mission-critical)
- **automated_failover** - justified by `aws-reliability-pillar` (driver: criticality=mission-critical)
- **health_check** - justified by `aws-reliability-pillar` (driver: criticality=mission-critical)
- **frequent_backup** - justified by `aws-rpo-rto-targets` (driver: data_loss_tolerance=minutes)
- **multi_region** - justified by `aws-reliability-pillar` (driver: international_users_at_scale)
- **latency_based_routing** - justified by `aws-reliability-pillar` (driver: international_low_latency)

## Security

- **encryption_at_rest** - justified by `nist-800-53` (driver: data_sensitivity=confidential)
- **encryption_in_transit** - justified by `nist-800-53` (driver: data_sensitivity=confidential)
- **access_control** - justified by `nist-800-53` (driver: data_sensitivity=confidential)

## Observability (Logging & Analysis)

- **monitoring** - justified by `google-sre-book` (driver: baseline)
- **centralized_logging** - justified by `opentelemetry-docs` (driver: baseline)
- **distributed_tracing** - justified by `opentelemetry-docs` (driver: criticality_or_event_driven)
- **slo_alerting** - justified by `google-sre-book` (driver: criticality=mission-critical)
- **access_logging** - justified by `nist-800-53` (driver: data_sensitivity=confidential)

## Testing

- **unit_testing** - justified by `fowler-test-pyramid` (driver: baseline)
- **integration_testing** - justified by `fowler-test-pyramid` (driver: baseline)
- **contract_testing** - justified by `enterprise-integration-patterns` (driver: services_integrate)

## Dependency Versioning (Futureproofing)

- **dependency_pinning** - justified by `semver` (driver: baseline)
- **automated_dependency_updates** - justified by `google-eng-practices` (driver: baseline)
- **compatibility_testing** - justified by `semver` (driver: baseline)

## Distributed-Systems Patterns

- **saga** - justified by `fowler-event-sourcing` (driver: event-driven+mission-critical)
- **event_sourcing** - justified by `fowler-event-sourcing` (driver: event-driven+mission-critical)

## Conformance summary

- Decisions: **51**
- Every decision cited: **true**
- World-class authorities cited (17): `aws-reliability-pillar`, `aws-rpo-rto-targets`, `aws-well-architected`, `azure-data-store-models`, `enterprise-integration-patterns`, `fowler-event-sourcing`, `fowler-test-pyramid`, `google-eng-practices`, `google-sre-book`, `microsoft-rest-api-guidelines`, `nist-800-53`, `oauth2-oidc`, `opentelemetry-docs`, `owasp-asvs`, `owasp-secure-headers`, `patterns-of-distributed-systems`, `semver`
