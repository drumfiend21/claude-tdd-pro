---
name: Architecture backlog — language-agnostic standards applied to all languages & frameworks
description: Future ticket for Claude TDD Pro — every general, language- & framework-agnostic software-engineering standard/pattern that CTP enforces today (currently via JS/TS-centric detectors) must be enforced across ALL languages and frameworks (Python, Go, Rust, Java, C#, Ruby, …) when CTP designs architecture or writes code to disk. Home the agnostic principles in the `_universal` namespace and give each a polyglot detector backend, dispatched through the §28.17 enforce.sh contract.
type: project
originSessionId: session_01FCfQeRYwwML6yrycar3vDL
status: backlog
---

# Ticket — universal (polyglot) enforcement of language-agnostic standards

**One line:** the general software-engineering principles CTP already enforces are
*language-agnostic*, but their detectors are *language-specific* (mostly JS/TS). Make every
agnostic principle apply to **all** languages and frameworks so that anything CTP designs or
writes to disk — in any language — is held to the same standard.

## Problem (grounded in today's surface)

CTP enforces general SE principles, but the enforcement is JS/TS-centric (per H-5: JS/TS/Python
first-class, the rest partial). The *principle* is agnostic; the *detector* is not:

| Agnostic principle | Today's detector (scope) | Should also cover |
|---|---|---|
| No untyped escape hatch | `no-any.sh` (`: any` in `.ts`) | Python `Any`/untyped, Go `interface{}`, TS `any`, etc. |
| Errors wrapped meaningfully, not raw | `naked-throw.sh` (`.ts`) | Python bare `raise Exception`, Go un-wrapped `errors.New`, Java raw `throw` |
| Validate external input at the boundary | `boundary-schema.sh` (node) | any language taking untrusted input into a sink |
| No hardcoded secrets in source | `boundary-schema.sh`/secrets (`.ts`) | every language |
| No debug print in production source | `console-in-src.sh` (`.ts`) | Python `print`, Go `fmt.Println`, Java `System.out` |
| Network calls have timeouts | `fetch-timeout.sh` (`.ts`) | any language's HTTP client |
| Dependencies pinned / lockfile integrity | `supply-chain.sh` (npm) | pip/poetry, go.mod, Cargo, Maven/Gradle |
| ADR structural + citation discipline | `adr-structure.sh` / `doc-citation-presence.sh` | already agnostic (Markdown) ✓ |
| EO/IaC security conventions | `cloud-guidance-rule.sh` | already cross-cloud ✓ |

So a Python / Go / Rust / Java service written to disk by CTP is **not** held to the agnostic
standards that a TypeScript service is — even though the standards themselves are universal. The
`_universal` namespace exists for exactly these cross-cutting rules but currently ships **no
`g-universal-*` rules** (only `ai-dev-corpus.md`).

## Scope

1. **Exhaustive, default-to-universal classification (no rule slips through).** This is the
   load-bearing requirement: the operator's curated first-class sources (OWASP, Google, US/federal,
   NIST, SLSA, …) must be enforced on **all** written code, and **no source rule may be silently
   omitted**. The method is *not* a hand-picked subset — it is a complete, gated classification:
   - **Enumerate the full corpus.** Start from EVERY rule in EVERY `generated-code-quality-standards/<namespace>/*.yaml`
     (the complete `active.json` set — google, owasp, us-government, slsa, security-governance, node,
     typescript, react, … — currently ~44 and growing), not a sample.
   - **Default = universal (opt-out, not opt-in).** Every rule is treated as language/framework-AGNOSTIC
     and enforced on all languages **unless** it carries an explicit `universality: language-specific`
     tag with a recorded `reason` (e.g. "React hook dependency analysis — framework-bound";
     "TS structural-type exhaustiveness — typed-language-bound"). Inverting the default is what closes
     the cracks: a rule that nobody classified is enforced everywhere by default, never dropped.
   - **Tag the corpus.** Add a `universality: universal | language-specific` field (with `reason` +
     `applies_languages` when specific) to the §2.1 rule schema, populated per rule, sourced from the
     rule's authority + detector semantics — not invented.
   - **Completeness gate (the guarantee).** Ship `rubric/detectors/audit-universality-coverage.sh`:
     it fails if ANY rule in the corpus lacks a `universality` classification. Wired into `/doctor` +
     CI (the three-surface contract). Because it runs on every change, **a newly added source rule
     also cannot slip through** — the gate goes red until it is classified. This makes "catch
     everything from the existing sources" a mechanically-enforced invariant, not a one-time audit.
2. **Home the universal set in `_universal`.** Every rule classified `universal` gets a `g-universal-<slug>`
   rule in `generated-code-quality-standards/_universal/`, grounded in its originating source authority
   (provenance preserved — an OWASP rule stays OWASP-cited), so it flows through `standards-sync` →
   `active.json` and is scopable by a consumer (§28.17 Correction 4). The originating per-source rule and
   its universal projection are cross-linked so the provenance chain to OWASP/Google/federal is intact.
3. **Polyglot detector backends.** Give each `g-universal-*` rule a detector that enforces the principle
   across languages. Options to weigh per principle: (a) per-language detector implementations behind one
   rule id; (b) an AST/tree-sitter polyglot detector (one principle, many grammars); (c) a language-detect
   shim routing to the right backend. A `universal` rule with no working backend for a present language is
   `not_enforced` (RED, per §28.18) — never a vacuous pass — so coverage gaps are visible, not hidden.
4. **Dispatch across all file types.** Extend the §28.17 `rubric/enforce.sh` namespace→glob map so
   `g-universal-*` rules evaluate every supported source extension (`.py`, `.go`, `.rs`, `.java`,
   `.rb`, `.cs`, …), honoring the §28.18 4-state (`not_applicable` when a language is absent).
5. **Architecture-design side.** Confirm the cloud-architect translation layer already emits the
   agnostic concerns (testing, auth/z, input validation, observability, dependency versioning) in a
   framework-neutral form, and that the build/enforce path applies them regardless of target stack.
6. **Honesty.** Update H-5 / `/doctor` coverage messaging as each language graduates from partial to
   first-class for the universal principle set; report per-language × per-principle coverage so the
   operator can see exactly what is enforced where.

## Acceptance criteria

- **Completeness:** `audit-universality-coverage.sh` passes only when EVERY rule in the corpus is
  classified `universal` or `language-specific:<reason>` — and is wired into CI so future-added source
  rules cannot land unclassified. (This is the "nothing slips through the cracks" guarantee.)
- **Default-to-universal proven:** a rule with no explicit `language-specific` tag is enforced on all
  languages — demonstrated by adding a fresh source rule with no tag and showing it is enforced
  everywhere by default (and that the gate would catch a missing classification).
- For each `universal` principle, `enforce.sh --root <app> --rule g-universal-<slug>` returns `fail`
  on a violating fixture in **every** supported language and `pass` on a clean one — specs with
  per-language fixtures (Python/Go/Rust/Java at minimum, beyond JS/TS).
- The `g-universal-*` rules keep their originating-source provenance (pass the §2.33 citation auditor)
  and reach `active.json`.
- A present language with no detector backend for a `universal` rule is `not_enforced` (RED), never a
  vacuous green; an absent language is `not_applicable` (§28.18).
- H-5 honesty + `/doctor` coverage report per-language × per-principle reach.

## Dependencies & sequencing

- **Builds on** the §28.17/§28.18 `enforce.sh` contract (the external-tree, catalog-keyed, 4-state
  dispatcher) and the §28.15 S-7 promotion pattern (how rules enter `generated-code-quality-standards/`).
- Pairs with H-5 (multi-language honesty) — this ticket is what lets H-5 truthfully widen.
- Likely a multi-CL effort (one principle or one language-family per CL, test-first per the workflow
  loop), candidate for a dedicated `docs/design/<version>-universal-polyglot-standards.md` when picked up.

## Out of scope (explicitly)

- Language-*specific* idiom lint (e.g. React hook deps, TS-only `exhaustive-unions`) — those stay
  per-namespace; only the *agnostic* principles generalize.
- Net-new principles not already enforced by CTP — this ticket generalizes the *existing* agnostic
  standard set across languages, it does not invent new standards.

Persisted as a backlog ticket (not ratified surface); promote to a `docs/design/` amendment + §28.x
reference when scheduled, following the append-only discipline.
