# 0001. Adopt balanced hybrid for a marketplace app connecting dog owners with trusted local dog walkers

- Status: accepted
- Date: 2026-06-08T12:00:00Z
- Pillar: security

## Context

Cloud design decision concerning the security Well-Architected pillar.
Grounding sources (cloud-architecture catalog): aws-architecture-center, aws-prescriptive-security, aws-well-architected, azure-well-architected, dod-scca, gcp-architecture-framework, nist-zero-trust.

## Considered Options

- Cost-optimized managed baseline
- Resilient scale-out
- Maximum-resilience multi-region

## Decision Outcome

Chosen: Balanced hybrid

Rationale: data_sensitivity=confidential; criticality=mission-critical; data_loss_tolerance=minutes; international_users_at_scale; international_low_latency; scale=large; public_facing_fast_requests; baseline; criticality_or_event_driven
