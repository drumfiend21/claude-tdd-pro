# First-principles derivation

Per the simulated Musk-team review: derive the system from physics
(or its software analog: information theory + customer behavior),
not from analogy. This document is the test of whether the system's
existence is justified.

## The customer problem (one paragraph)

A developer writes code with AI assistance. AI-generated code looks
plausible but often misses standards that experienced engineers
internalize: error handling discipline, public-API stability, naming
conventions, security-aware defaults. The developer wants their AI
collaborator to **already know** these standards and **emit
compliant code on the first try.** When the AI deviates, the
developer wants to know within seconds, not at code review time.

## What this means in information-theoretic terms

The standard exists as text somewhere (Google's eng-practices guide,
OWASP top 10, etc.). The AI has been trained on a snapshot of the
internet that includes that text. The deviation gap is the
difference between **what the AI internalized** and **what the
standard authoritatively says today**. The gap grows over time
(standards evolve; training data doesn't). It also grows by domain
(a generalist model knows a little about HIPAA, a lot about JS
style; a specialist would invert this).

## The minimum viable solution (from first principles)

To close the gap, three things must exist:

1. **A current snapshot of the standard.** Pulled from the
   authoritative source, dated, and verifiable. (Not training-data;
   real-time fetched.)
2. **A way to confront the AI with that snapshot during code
   generation.** Either by injecting it into the prompt or by
   judging the output against it.
3. **A signal to the developer when the output deviates.** Not at
   PR time. As the code is being written.

These three are the entirety of the load-bearing requirement.
Everything else in the system is an optimization or a
convenience.

## What the system delivers

| First-principles need | System component | Necessary or convenience? |
|---|---|---|
| Current snapshot | `generated-code-quality-standards/` + S-2 fetcher | **Necessary** |
| Confronting the AI | `RUBRIC.yaml` gating + hooks | **Necessary** |
| Deviation signal | LSP / hook / CI gate | **Necessary** |
| Profile policy | `profiles/` | Convenience (multi-domain) |
| Compliance frameworks | C phase | Convenience (regulated industries) |
| PR-corpus learning | L phase | Convenience (organizational learning) |
| SPACE telemetry | Q phase | Convenience (operator observability) |
| Cost telemetry | H-12 + N phase | Convenience (budget transparency) |
| Standards source contract | §2.6 | **Necessary** (provenance) |
| Fidelity audit | §25 fidelity gate | **Necessary** (defends drift) |

About 60% of the system's surface area is convenience. **That is not
a critique — convenience compounds.** But it should be named so
that a v2 simplification target is visible: the 40% that is
load-bearing is the minimum viable.

## Where the system violates first principles

1. **The runner is grep-based, not AI-based.** A first-principles
   solution to "judge code against a standard" is to ask an LLM:
   "Read this code. Read this rule. Does the code satisfy the rule?
   Justify." We instead built 50+ shell-script detectors that
   pattern-match. This works for syntactic rules; it fails for
   semantic ones. The `rubric/detectors/llm-judge.sh` scaffold
   (shipped in this CL) starts to fix this.

2. **The architecture is heavy.** The first-principles solution has
   5 components. The system has 26 phases and 27 contracts. The
   `docs/ARCHITECTURE.md` compression (also this CL) is the
   visible-to-operators consequence.

3. **The plugin model creates platform-dependency.** A
   first-principles solution does not require Claude Code to exist.
   It requires only an LSP-speaking editor, a CI runner, and a
   pre-commit hook surface. The `docs/PLATFORM_DEPENDENCY.md`
   abstraction layer (also this CL) describes the path to platform
   independence.

## What's exceptional vs. first principles

1. **The drift catalog in CLAUDE.md.** Mindfulness about
   failure-modes is not derivable from first principles; it's a
   distillation of experience. The catalog is empirically derived
   and is the most defensible part of the architecture.
2. **The fitness-function discipline.** Same — derived from
   Parsons/Ford evolutionary architecture work, but applied
   concretely. Not over-engineered; load-bearing.
3. **The cl-build orchestrator.** The cycle time enabled by it is
   real and measurable.

## The 5-step algorithm applied

1. **Make requirements less dumb.** The customer journey is three
   sentences. We documented it as such.
2. **Delete the part or process.** Archived 144 shape-only specs in
   this CL; called out 60% of system as convenience for a future
   simplification CL.
3. **Simplify or optimize.** ADR-0001 (bash runner) is the optimize-
   later candidate; ADR-0001 §rollback names the Go/Rust rewrite as
   the optimize step.
4. **Accelerate cycle time.** cl-build.sh + the lockfile model do
   this. The benchmark in `scripts/bench.sh` measures it.
5. **Automate.** Fitness functions, drift gates, release workflow,
   weekly trend cron — all automated.

We started at step 3 (per Elon's review). The architecture
compression in this CL is step 2 work being done out of order. The
next CL should be a true step 2 pass: delete more, not just
re-organize.
