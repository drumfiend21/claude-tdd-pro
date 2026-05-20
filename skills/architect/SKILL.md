---
name: architect
description: Interactive architecture elicitation. Decomposes a feature description into decision points, enumerates grounded options per S/L/C source, prompts the operator per decision, and writes ADRs.
trigger: explicit
---

# Architect skill

Per architecture §16 W-1. Inputs:
- Free-form feature or architecture description (operator argument).
- Active profile (for option narrowing).
- Resolved standards / PR-corpus / compliance grounding registry.

## Flow

1. **Decompose** the input into discrete decision points.
2. **Enumerate options** per decision point, each grounded in a citation:
   - `standard:<source-id>` (S phase)
   - `pr:<url>` (L phase)
   - `control:<framework>:<control-id>` (C phase)
3. **Narrow** options against the active profile (drops incompatible options).
4. **Decline** any decision that has no S/L/C grounding (architect refuses to
   speculate without evidence; surfaces a "no grounding available" message).
5. **Prompt** the operator interactively, one decision at a time.
6. **Write ADRs** to `docs/adr/<NNNN>-<slug>.md`, one per decided point.
7. **Hand off** to `/spec` → `/plan-first` → `/feature` in that exact order.

## Subagent

`agents/architect.md` (sonnet, `prompt_id: architect-elicitor`,
`prompt_version` per §2.10). W-1.11.1 anti-hallucination eval must pass
before this skill is enabled in any default profile.
