# Architecture v2 — pruned

Per the simulated Musk + Fowler joint review:
> "The 26 architecture phases and 27 cross-cutting contracts should
>  be ranked by customer impact and pruned aggressively — the
>  documentation tier is heavier than the customer journey, which is
>  a reliable signal of optimization without enough prior deletion."

This is the pruning. **v2 ships 5 phases and 5 cross-cutting
contracts.** Everything else from v1.9 is preserved in
`docs/architecture-v1.9.md` (governance) and `docs/architecture-v2/
_archived/` (per-phase rationale for what was cut and when).

## The five phases

1. **G — Generated standards.** The rubric source-of-truth tree at
   `generated-code-quality-standards/`. Without this, there is no
   rule to enforce.
2. **F — Enforcement.** The rubric runner at `rubric/runner.sh`
   (migrating to `runner-go/`). Without this, the rules are inert.
3. **X — Surfaces.** LSP, hooks, CI. Without this, the runner is
   invisible to operators.
4. **H — Profiles.** `profiles/` + `.claude-tdd-pro/userConfig.yaml`.
   Without this, one rubric is forced on every operator.
5. **E — ESLint integration.** Without this, the JS ecosystem
   (which is where most operators land first) is unreached.

That's it. Five phases, each with a clear customer-journey
justification.

## The five cross-cutting contracts (Tier 1)

Carried over verbatim from `docs/CONTRACT_PRIORITIES.md`:

1. **§2.1 — Rubric rule schema.** Without this, rule provenance is
   unverifiable.
2. **§2.25 — Pending-spec content fidelity.** Without this, drift
   mechanism #6 ships.
3. **§2.14 — Destructive command dry-run.** Without this, operator
   state is unrecoverable.
4. **§2.17 — Freshness gate.** Without this, citations rot.
5. **§2.21 — Source-file validation.** Without this, malformed
   standards files break rules silently.

## What was deleted (and where to find it)

| Cut | Rationale | Preserved in |
|---|---|---|
| Phase C — Compliance | Convenience for regulated industries; not load-bearing | `docs/architecture-v1.9.md` §3 |
| Phase P — Prompts | Operator-facing prompt lifecycle; orthogonal to enforcement | §6 |
| Phase R — Risk profiles | Subset of H (profiles); merged | §7 |
| Phase N — Cost telemetry | Subset of H-12 / Q-12 (observability) | §8 |
| Phase T — Type rules | Subset of E (ESLint integration with TS) | §9 |
| Phase Q — SPACE telemetry | Operator-facing observability; not enforcement | §10 |
| Phase H — Hardening | Subset of "operational maturity" + ADR work | §11 |
| Phase L — PR learning | Long-term loop; valuable, not load-bearing | §12 |
| Phase O — Operational | Distribution + audit + uninstall; convenience | §13 |
| Phase W — Workflow | Architect agent + ADR + concurrent CL | §15 |
| Phase S — Standards source | Subsumed by G + the S-2 fetcher | §16 |
| Cross-cutting §2.2..§2.13, §2.15, §2.16, §2.18..§2.24, §2.26, §2.27 | Tier 2/3 per `docs/CONTRACT_PRIORITIES.md` | §2.X |

## What this means for existing work

- **All existing features stay.** The pruning is **conceptual**, not
  destructive. The 193 architecture features in v1.9 keep their
  substrate, their specs, and their fitness function coverage.
- **The customer-facing description** uses v2's 5 phases. The
  governance reference uses v1.9.
- **New CLs** can target either v2 phases (operator-visible) or v1.9
  features (governance / amendment work). The CL-build orchestrator
  already accepts both.
- **The §25 fidelity gate** still reads v1.9 as the authoritative
  vocabulary source. v2 is a customer-facing compression, not a
  vocabulary replacement.

## The Fowler note

> "Aggressive deletion is the right discipline for the operator-
>  facing surface. The governance text is a separate artifact for a
>  separate audience. Both are correct; they're just different
>  documents."

## The Musk note

> "If we can't explain the system in 5 phases, we don't understand
>  what it's for. We can now."
