# Architecture-text gaps for v2.0 enumeration

This file tracks features whose v1.9 architecture text is too sparse to
test concretely without inferring decomposition. Per CLAUDE.md drift
mechanism #1 ("compaction loss + inferred decomposition"), inferred
specifics are the exact failure mode that bit CL-08/09/10. This list
records places where v1.9 needs a v2.0 enumeration, so future CLs do
not silently invent specifics.

## Surfaced in CL-30b drift audit (2026-05-13)

### L-11 — Anti-poisoning safeguards consolidated

**§12 text:** "Anti-poisoning safeguards consolidated." (5 words, no
enumeration)

**Gap:** v1.9 does not name the specific safeguard kinds. CL-30 initially
invented four (single-author-dominance, self-approval, intra-org-only,
rapid-merge); CL-30b removed those and replaced with safeguard-agnostic
behavior tests (data-driven check registration, structured emission, exit
code contract, --list-checks introspection).

**v2.0 enumeration request:** §12 should list the specific safeguard
kinds that ship by default, modeled on the 10-default-source pattern of
L-1 or the 11-feature pattern of H. Suggested floor based on PR-corpus
threat-model literature (NOT in v1.9 text — would need architecture-team
vetting before promotion):
- single-author-dominance (one author authored >X% of supporting PRs)
- self-approval (PR author = approving reviewer)
- intra-org-only (every reviewer affiliated with author org)
- rapid-merge (merge time < threshold from open)
- review-comment-stuffing (boilerplate comments inflating substantive count)
- coordinated-org-cluster (small set of orgs always co-citing each other)

### L-15 — Cross-loop integration

**§12 text:** "Cross-loop integration." (3 words, no enumeration)

**Gap:** v1.9 does not name the cross-loop targets, the documentation
artifact for cross-loop wiring, or per-target operator controls. CL-30
initially invented `pr-corpus/cross-loop-map.yaml`; CL-30b removed it and
replaced with a behavior-only spec on cross-loop emission origin tagging.

**v2.0 enumeration request:** §12 (or a new cross-cutting §2.X) should
specify:
- The cross-loop emission contract (what fields every cross-loop event
  carries — tentatively: origin, source_pattern_id, consumers list,
  emission timestamp).
- The set of consumers (Standards loop, Compliance loop, Rubric loop,
  SPACE dashboard, Workflow state machine) and what each consumes from
  pr-corpus.
- Whether cross-loop wiring is documented in code, in `cross-loop-map.yaml`,
  in the architecture text comments, or via convention only.
- Per-target operator-disable semantics (should this live in the profile
  system §2.5, in PR-SOURCES.yaml, or in a new file?).

## Process note

CLAUDE.md drift mechanism #1: when architecture text for a feature is
under ~15 words, inferred decomposition is the most likely failure mode.
Test discipline going forward: if the §12-style entry is sparse, write
specs that test only the verb in the entry ("consolidated", "integrated")
plus cross-cutting contracts, and add a BACKLOG.md note for the missing
enumeration. Do NOT invent specifics from domain knowledge.
