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

## Surfaced in CL-31/32/33 drift audit (2026-05-13)

### W-5 — Profile registration (sparse-text gap)

**§15 text:** "Profile registration." (2 words, no enumeration)

**Gap:** §2.5 profile system contract does not specify a `workflow_stages`
field. CL-32 W-5 specs invented a `workflow_stages: [architect, plan, build,
review, merge]` profile-yaml field and a `--list-stages` enumeration. The
field name and the stage enumeration are inferred from the W phase's
naming convention (W-1 architect, etc.), not from the architecture text.

Specs use regex alternation so they're tolerant of any future
implementation, but the field name itself is invention. Same drift
mechanism #1 that bit L-11 / L-15.

**v2.0 enumeration request:** §15 should specify how W components
register themselves in the profile system §2.5. Possibilities:
- Add a `workflow_stages` field to §2.5 with explicit enum.
- Use the existing §2.5 `include` block with a `workflow_stages` sub-key.
- Make registration implicit (no profile field; W components register at
  install time via a side-effect of the W command being installed).
- Some other mechanism not yet enumerated.

The decision affects whether the W-5 specs need rewriting at
implementation time or whether they're already correctly testing the
shape that §2.5 will eventually adopt.

## Surfaced in CL-33b broader cleanup sweep (2026-05-13)

### Pre-existing opaque-ID violations across pending tree (239 specs)

**Scope:** A broader audit sweep found 239 spec names project-wide that
contain opaque-ID cross-references (parentheticals like `(§5 C-1)`,
`(C-4 + C-3 / §2.8)`, `(per X-1)`, `(cross-ref H-1 transparency)`, or
bare opaque IDs in the middle of names like `via S-2 fetcher`,
`L-22 (PR corpus)`, `C-19 (compliance)`).

**Distribution by phase:** C: 53, G: 32, R: 31, S: 31, T: 26, N: 21,
E: 13, P: 10, O: 7, F-0: 5, CC: 4, X: 4, F-1: 1, F-2: 1.

**Attribution:** ALL 239 are in pre-existing folders (not introduced by
CL-30, CL-30b, CL-31, CL-32, or CL-33). They are CL-08/CL-09 era
violations that survived CL-11 cleanup because CL-11 only deleted
INVENTED FOLDERS (where the folder name didn't trace to architecture).
The folder names here are correct; only the spec NAMES carry opaque
cross-references.

**CL-33b scope:** CL-33b cleared the 23 violations the initial drift
audit found (in H-9, O-0/1/2/3/11, X-1/2/3, and via the wider sweep
two more in H-9 and O-0). The remaining 239 are deferred to a future
project-wide opaque-ID-cleanup CL because the user explicitly approved
only the 23-fix scope; expanding mid-cycle would violate the
no-scope-creep discipline.

**v1.9 cleanup request:** A future CL should systematically rewrite the
239 spec names to use descriptive labels in place of opaque IDs.
Mechanical sweep with a curated cross-reference replacement table
(e.g., `S-2` → `the standards fetcher`, `H-1 transparency` → `token-cost
transparency`, `C-4` → `the merkle-chained audit log`, `§2.7` → `the
sectioned advisory lock contract`). The sweep is risk-free because
spec NAMES don't affect spec BEHAVIOR (the spec body is what runs);
only audit cleanliness improves.

## Process note

CLAUDE.md drift mechanism #1: when architecture text for a feature is
under ~15 words, inferred decomposition is the most likely failure mode.
Test discipline going forward: if the §12-style entry is sparse, write
specs that test only the verb in the entry ("consolidated", "integrated")
plus cross-cutting contracts, and add a BACKLOG.md note for the missing
enumeration. Do NOT invent specifics from domain knowledge.

CLAUDE.md Step 1 ("no opaque IDs in names") is a project-wide rule, not
a per-CL rule. Audit regex must catch parenthetical cross-references
(`(§5 C-1)`, `(per X-N)`, `(cross-ref Y-N)`) as well as the simpler
trailing-paren form. The CL-30b regex caught the simpler patterns;
CL-33b broadened the regex to catch all variants. Future generators
should validate spec names against the broadened regex before commit.
