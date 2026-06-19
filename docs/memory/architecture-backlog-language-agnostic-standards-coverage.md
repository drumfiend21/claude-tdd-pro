---
name: Architecture backlog — apply all rules to all generated software, withhold only the not-agnostic-and-not-general
description: Future ticket for Claude TDD Pro — apply EVERY enforced rule from the curated first-class sources (OWASP, Google, US/federal, NIST, SLSA, …) to ALL generated software-engineering content (architecture, design, ADRs, IaC, config, and code) across ALL languages, frameworks, and technologies. Withhold a rule from a target ONLY when it is BOTH not language/framework/tech-agnostic AND not a generally-applicable principle. A CI completeness gate makes the withhold set explicit and justified so nothing from the sources slips through.
type: project
originSessionId: session_01FCfQeRYwwML6yrycar3vDL
status: backlog
---

# Ticket — apply all rules to all generated software; withhold only the narrowly-bound

**One line:** **apply every enforced rule to all generated software-engineering content** —
architecture, design, ADRs, IaC, config, and code — across **all** languages, frameworks, and
technologies (any generated content that contributes to creating a software application). **Withhold
a rule from a given target only when it is BOTH not agnostic AND not a generally-applicable rule.**
Everything else is enforced everywhere, by default.

## The rule (precise)

For every (rule × generated-target) pair, **enforce by default.** Withhold ONLY if **both** hold:

1. the rule is **not agnostic** — genuinely bound to one language / framework / technology and not
   expressible against the target; **AND**
2. the rule is **not a generally-applicable principle** — it does not encode a general engineering
   standard that maps onto the target.

This is a **conjunction**: a rule that is agnostic *or* generally-applicable is **applied**. Only a
rule that is *both* tech-bound *and* narrow (e.g. React hook-dependency analysis on a Go file) is
withheld — and then only with a recorded justification. This is deliberately the most inclusive
possible default; the burden of proof is on *withholding*, never on *applying*.

> Note vs the earlier draft: this is broader than "promote the agnostic subset." Even a rule whose
> *current detector* is language-specific (e.g. `naked-throw` in `.ts`) is **applied** to other
> languages, because the *principle* (errors wrapped meaningfully, not raw) is generally applicable —
> its enforcement just needs a per-language realization. It is NOT withheld.

## Why (grounded in today's surface)

CTP enforces first-class-source standards, but enforcement is JS/TS-centric (H-5: JS/TS/Python
first-class, the rest partial). The *standard* is generally applicable; the *detector* is bound:

| Standard (source) | Today's detector (scope) | Applies to (under the rule above) |
|---|---|---|
| No untyped escape hatch | `no-any.sh` (`.ts`) | every typed/partially-typed language (Python `Any`, Go `interface{}`, …) |
| Errors wrapped, not raw | `naked-throw.sh` (`.ts`) | every language with exceptions/errors |
| Validate input at the boundary (OWASP) | `boundary-schema.sh` (node) | every language taking untrusted input |
| No hardcoded secrets (OWASP) | secrets (`.ts`) | every language |
| No debug print in src (Google) | `console-in-src.sh` (`.ts`) | every language |
| Network calls time out | `fetch-timeout.sh` (`.ts`) | every language's HTTP client |
| Dependencies pinned (SLSA) | `supply-chain.sh` (npm) | pip/go.mod/Cargo/Maven/… |
| ADR structure + citation | `adr-structure` / `doc-citation-presence` | all generated design docs ✓ |
| EO/IaC security conventions (federal) | `cloud-guidance-rule.sh` | all IaC, cross-cloud ✓ |

So a Python / Go / Rust / Java service — or any non-TS generated artifact — is **not** currently held
to standards that a TypeScript service is, even though the standards are generally applicable. The
`_universal` namespace exists for exactly this and currently ships no `g-universal-*` rules.

## Scope

1. **Enumerate the full corpus (no rule slips through).** Operate over EVERY rule in EVERY
   `generated-code-quality-standards/<namespace>/*.yaml` — the complete `active.json` set (google,
   owasp, us-government, slsa, security-governance, node, typescript, react, … ; ~44 today and
   growing) — not a sample.
2. **Apply-by-default; tag only withholds.** Add an `enforcement` field to the §2.1 rule schema:
   absent / `apply` = enforced on all generated targets (the default); `withheld` requires a
   structured justification proving the conjunction — `{ reason, bound_to: <lang|framework|tech>,
   not_general_because: <…> }`. A rule with no `withheld` tag is enforced everywhere — forgetting to
   classify can only ever *over*-enforce, never drop a source standard.
3. **Completeness + correctness gate (the guarantee).** Ship
   `rubric/detectors/audit-universality-coverage.sh`, wired into `/doctor` + CI (three-surface
   contract): (a) every rule is either applied-by-default or carries a *complete* `withheld`
   justification (both conjuncts present); (b) a `withheld` tag whose justification fails the
   conjunction (the rule is actually agnostic OR generally-applicable) is REJECTED. Because it runs on
   every change, a newly-added source rule cannot land withheld-without-cause, and cannot silently
   drop. This makes "apply everything from the sources" a mechanically-enforced invariant.
4. **Realize each applied rule on each target.** For every applied rule × language/technology, provide
   a detector backend that enforces the standard there. Per principle, weigh: (a) per-language detector
   implementations behind one rule id; (b) an AST/tree-sitter polyglot detector; (c) a language-detect
   shim. Home the cross-target projections under `_universal/` (`g-universal-<slug>`) with the
   **originating-source provenance preserved** (an OWASP rule stays OWASP-cited; passes §2.33). An
   applied rule with no backend yet for a *present* target is `not_enforced` (RED, §28.18) — never a
   vacuous green — so the gap is loud, not hidden.
5. **All generated targets, not just code files.** "Generated software-engineering content that
   contributes to a software application" = architecture decisions, design docs/ADRs, IaC, config,
   schemas, AND source code. Extend the §28.17 `enforce.sh` dispatch so applied rules evaluate every
   relevant target type/extension, honoring the §28.18 4-state (`not_applicable` when a target type is
   absent). Confirm the cloud-architect design path applies the standards regardless of target stack.
6. **Honesty.** H-5 / `/doctor` report per-target × per-rule coverage so the operator sees exactly
   what is enforced where, and which rules (and why) are withheld.

## Acceptance criteria

- **Apply-by-default proven:** add a fresh source rule with no `enforcement` tag → it is enforced on
  ALL generated targets/languages automatically (forgetting to classify over-enforces, never drops).
- **Withhold is the only exception, and it is justified:** `audit-universality-coverage.sh` passes
  only when every `withheld` rule carries a complete conjunction justification, and REJECTS a withhold
  on a rule that is agnostic or generally-applicable. Wired into CI so this holds for future rules.
- For each applied standard, `enforce.sh --root <target> --rule <id>` returns `fail` on a violating
  fixture and `pass` on a clean one **in every relevant language/target** (Python/Go/Rust/Java at
  minimum, plus a non-code generated target) — proven by per-target fixtures.
- Applied rules keep originating-source provenance (pass the §2.33 citation auditor) and reach
  `active.json`.
- A present target with no backend for an applied rule is `not_enforced` (RED), never vacuous green;
  an absent target is `not_applicable` (§28.18).

## Withheld set (the ONLY exemption — small, explicit, justified)

A rule is withheld from a target only when it is **both** tech-bound **and** narrow. Examples that
likely qualify (each must still carry its recorded justification, and only for targets where both
conjuncts hold): React hook-dependency analysis (framework-bound + narrow) on non-React targets;
TS structural-type exhaustiveness on untyped targets. Anything expressing a general standard — error
handling, input validation, secrets, logging, timeouts, dependency pinning, naming, complexity,
testing, documentation — is **applied**, never withheld.

## Dependencies & sequencing

- Builds on the §28.17/§28.18 `enforce.sh` contract (external-tree, catalog-keyed, 4-state dispatcher)
  and the §28.15 S-7 promotion pattern (how rules enter `generated-code-quality-standards/`).
- Pairs with H-5 (multi-language honesty) — this ticket is what lets H-5 truthfully widen.
- Multi-CL effort (one standard or one language/target-family per CL, test-first per the workflow
  loop); candidate for a dedicated `docs/design/<version>-universal-polyglot-standards.md` when picked up.

Persisted as a backlog ticket (not ratified surface); promote to a `docs/design/` amendment + §28.x
reference when scheduled, following the append-only discipline.
