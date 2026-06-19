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

1. **Taxonomy.** Enumerate the standards CTP enforces and classify each as *language-agnostic
   principle* vs *language-specific lint*. Only the agnostic set is in scope here.
2. **Home them in `_universal`.** Each agnostic principle becomes a `g-universal-<slug>` rule in
   `generated-code-quality-standards/_universal/` (grounded in its source authority — e.g. OWASP
   ASVS for input-validation/secrets, the corpus for error-handling), so the rules flow through
   `standards-sync` → `active.json` and are scopable by a consumer (per §28.17 Correction 4).
3. **Polyglot detector backends.** Give each `g-universal-*` rule a detector that enforces the
   principle across languages. Options to weigh (pick per principle): (a) per-language detector
   implementations behind one rule id; (b) an AST/tree-sitter-based polyglot detector (one grammar
   table, many languages); (c) a language-detection shim that routes to the right backend.
4. **Dispatch across all file types.** Extend the §28.17 `rubric/enforce.sh` namespace→glob map so
   `g-universal-*` rules evaluate every supported source extension (`.py`, `.go`, `.rs`, `.java`,
   `.rb`, `.cs`, …), honoring the §28.18 4-state (`not_applicable` when a language is absent).
5. **Architecture-design side.** Confirm the cloud-architect translation layer already emits the
   agnostic concerns (testing, auth/z, input validation, observability, dependency versioning) in a
   framework-neutral form, and that the build/enforce path applies them regardless of target stack.
6. **Honesty.** Update H-5 / `/doctor` coverage messaging as each language graduates from partial to
   first-class for the agnostic principle set.

## Acceptance criteria

- A taxonomy doc lists every CTP-enforced standard as agnostic-principle vs language-specific.
- For each agnostic principle, `enforce.sh --root <app> --rule g-universal-<slug>` correctly returns
  `fail` on a violating fixture in **every** supported language and `pass` on a clean one — proven by
  specs with per-language fixtures (Python/Go/Rust/Java at minimum, beyond JS/TS).
- The `g-universal-*` rules are grounded (pass the §2.33 citation auditor) and reach `active.json`.
- A non-present language is `not_applicable` (no vacuous green), per §28.18.
- H-5 honesty + `/doctor` coverage reflect the expanded language reach.

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
