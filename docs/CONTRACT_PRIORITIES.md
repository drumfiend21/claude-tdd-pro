# §2.X cross-cutting contract prioritization

Per Richards (*Fundamentals of Software Architecture*), architectural
characteristics ("the -ilities") must be ranked, not equally weighted.
Equal weighting produces decision paralysis when characteristics
conflict (e.g., the §2.7 lock contract conflicting with §2.23
concurrent-CL throughput).

This ranking applies when contracts conflict during a CL design
decision. It is **not** a list of which contracts the system enforces —
the system enforces all 27. It is the ranking by which trade-offs are
made.

## Tier 1 — Hard requirements (top 5)

Violations block merge. These are the load-bearing invariants without
which the system fundamentally misrepresents itself.

1. **§2.1 Rubric rule schema** — every rule shipped must satisfy this
   schema. Violations make rule provenance unverifiable.
2. **§2.25 Pending-spec content fidelity** — vocabulary in pending
   specs must trace to the architecture text. Violations are how
   CL-08/09/10 invented 297 wrong specs.
3. **§2.14 Destructive command dry-run** — every destructive command
   honors `--dry-run`. Violations risk unrecoverable operator state.
4. **§2.17 Freshness gate** — rules cannot activate against stale
   standards. Violations risk citation-rot.
5. **§2.21 Source-file validation** — generated standards files must
   validate per the file-schema before a rule is read from them.

## Tier 2 — Important (next 10)

Violations require ADR-level justification but do not block merge.

6. §2.2 Detector contract
7. §2.5 Profile config schema
8. §2.6 Standards source contract
9. §2.7 Sectioned advisory locks
10. §2.8 AI provenance manifest
11. §2.9 Controls mapping
12. §2.16 Decision provenance schema (MADR ADRs)
13. §2.24 Portable audit-pack format
14. §2.26 (v1.11 addition)
15. §2.27 (v1.11 addition; long-running agent harness)

## Tier 3 — Desirable (remaining 12)

Violations are tracked but do not require ADR justification.

16. §2.3 Subagent invocation
17. §2.4 ESLint domain glossary
18. §2.10 Risk tier
19. §2.11 SPACE metric schema
20. §2.12 PR source contract
21. §2.13 Active-flow stack
22. §2.15 Workflow state envelope
23. §2.18 Cost telemetry
24. §2.19 Inline suppression
25. §2.20 Operator extension namespace
26. §2.22 Compliance fetcher
27. §2.23 Concurrent-CL contract

## Conflict resolution

When two contracts conflict during CL design, the **lower-numbered
tier wins**, ties broken by listed order within tier. Example:

- Conflict: §2.7 (lock acquisition serializes work) vs §2.23
  (concurrent-CL throughput maximizes parallelism). §2.7 is Tier 2;
  §2.23 is Tier 3. **§2.7 wins.** The lock serialization is preserved;
  concurrent-CL throughput accommodates the lock.

## Review cadence

This prioritization is re-reviewed at each architecture amendment
(§23, §24, §25, §26, future). Re-ranking requires a governance CL and
explicit consensus from CODEOWNERS reviewers.

## Provenance

- Decision: 2026-06-04
- Reviewer: simulated Mark Richards code review (this CL)
- Architectural basis: Richards, *Fundamentals of Software Architecture*
  (O'Reilly, 2020), Chapter 4 (Architectural Characteristics) and
  Chapter 5 (Identifying Characteristics).
