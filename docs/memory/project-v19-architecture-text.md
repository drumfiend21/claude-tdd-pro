---
name: Claude TDD Pro v1.9 (+ v1.9.1 + v1.10 amendments) — full architecture text (pointer)
description: Pointer file. The canonical full architecture text lives at ../architecture-v1.9.md. This file exists to mirror the auto-memory naming convention so the repo memory tree parallels the per-user ~/.claude/projects/.../memory/ tree.
type: project
---

# Architecture text — canonical location

**Canonical:** [../architecture-v1.9.md](../architecture-v1.9.md)

This file is a pointer, not a copy. The architecture text is large (~1,000 lines) and maintaining two synchronized copies in the repo would invite drift. The single source of truth is `docs/architecture-v1.9.md`.

The auto-memory system at `~/.claude/projects/-Users-siddharthjoshi-projects-claude-tdd-pro/memory/project-v19-architecture-text.md` carries a verbatim mirror for cross-conversation context. When the repo file at `docs/architecture-v1.9.md` changes, the auto-memory mirror should be refreshed; the repo file is authoritative.

## What the architecture covers (chapter map)

- **§1** — Thirteen-layer system architecture (ASCII diagram)
- **§2** — Cross-cutting contracts (§2.1 through §2.24, including v1.9.1 amendments §2.23, §2.24)
- **§3** — Phase F: Foundation (F-0..F-6)
- **§4** — Phase S: Standards Ingestion & Reconciliation (S-1..S-19)
- **§5** — Phase C: Compliance, Audit & Provenance (C-1..C-21)
- **§6** — Phase P: Prompt Engineering & AI Component Lifecycle (P-1..P-10, P-10 added v1.10)
- **§7** — Phase R: React specialist coverage
- **§8** — Phase N: Node specialist coverage
- **§9** — Phase T: Type-level rigor
- **§10** — Phase Q: SPACE Productivity Measurement (Q-1..Q-9)
- **§11** — Phase H: Hardening, sustainability, honesty (H-1..H-12, H-12 added v1.9.1)
- **§12** — Phase L: Public Engineering Corpus Learning (L-1..L-24)
- **§13** — Phase O: Operational Readiness (O-0..O-12, O-12 added v1.10)
- **§14** — Phase X: Execution Surfaces (X-1..X-9, X-6/7 added v1.9.1, X-8/9 added v1.10)
- **§15** — Phase W: Workflow Orchestration (W-1..W-12, W-10 added v1.9.1, W-11/12 added v1.10)
- **§16** — Phase E: ESLint-Parity Rule Engine (E-1..E-17)
- **§17** — Phase G: Generated Quality-Standards Directory (G-1..G-14)
- **§18** — Cumulative file/component inventory at v1.9 + v1.9.1 + v1.10 deltas
- **§19** — Out of scope (irreducible 0.15 gap to 10.0)
- **§20** — Execution order (canonical staged path, weeks 1–30)
- **§21** — Definition of done
- **§22** — Confidence ranking summary
- **§23** — v1.9.1 optimization amendments (this addition, see §23.1–§23.8)
- **§24** — v1.10 surface expansion amendments (this addition, see §24.1–§24.7)

## Next available ID cursor (per §24.7)

After v1.10: P-11, X-10, W-13, O-13, H-13, plus any unused IDs in F/E/G/S/C/R/N/T/Q/L (unchanged from v1.9 base).

## Discipline reminder

Per `CLAUDE.md` and `feedback-self-gap-check-before-commit.md`: every CL must extract literal feature IDs and §2.X labels from the canonical text at `docs/architecture-v1.9.md`. No paraphrasing, no invention, no inferred decomposition.
