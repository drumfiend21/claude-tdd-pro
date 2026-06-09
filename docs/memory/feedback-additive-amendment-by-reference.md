---
name: Additive-amendment-by-reference (append-only constitution discipline)
description: How to evolve the canonical architecture and any constitution-class doc on Claude TDD Pro — write the detailed content as a NEW file, then APPEND a reference block to the constitution. Never delete or alter existing constitution content. Apply to all new and ongoing work.
type: feedback
---

**Apply to ALL new and ongoing work on Claude TDD Pro that touches a constitution-class document.**
Constitution-class docs are the append-only sources of truth: `docs/architecture-v1.9.md` (the canonical
architecture), and by extension `CLAUDE.md`, `generated-code-quality-standards/_universal/ai-dev-corpus.md`
(PRIMARY RULESET), and `docs/memory/MEMORY.md`.

## The rule

When introducing new surface, amendments, designs, or decisions:

1. **Write the detail into a NEW file.** Long-form rationale, requirement→mechanism mapping, spec sketches,
   ticket plans, contract text — these live in a new file (e.g. `docs/design/<version>-<slug>.md`), not
   inline-rewritten into the constitution.
2. **APPEND a reference block to the constitution.** Add a new, clearly-numbered section at the END of the
   canonical doc (e.g. `## §27. …`) that (a) registers the canonical IDs / contract numbers / vocabulary /
   anti-drift folder map that `CLAUDE.md` requires to be *extractable from the constitution itself*, and
   (b) links to the new file for the full text.
3. **Never delete or alter existing constitution content.** No existing §1–§N byte changes. Verify with
   `git diff --numstat <file>` → the deletions column MUST be `0`. The change is purely additive.

## Why

- The project's entire governance thesis is "ARCHITECTURE IS LAW" + the CL-08/09/10 drift catalog: the
  canonical file is edited deliberately and never drifted into. **Append-only is the strongest form of
  "never alter":** if no existing bytes change, no prior contract, ID, or decision can be silently mutated.
- It is exactly how the constitution already grew: §23 (v1.9.1), §24 (v1.10), §25 (v1.9.2), §26 (v1.11)
  are all appended amendment sections that reference and extend, never overwrite. §27 (v1.12) followed the
  same pattern — full design in `docs/design/v1.12-cloud-architecture-curriculum.md`, a reference block
  appended as §27 (29 insertions, 0 deletions, validated 2026-06-08).
- Reference-not-duplicate keeps the constitution scannable: IDs + vocabulary + folder map stay in the
  canonical file (so `CLAUDE.md` Step 0 extraction and the §25 auditor both work), while the bulky
  rationale lives in the linked design file (Musk "delete" — don't bloat the constitution).

## What MUST stay inline in the appended reference block (not only in the linked file)

Per `CLAUDE.md` these must be extractable from `docs/architecture-v1.9.md` directly, so the reference
block carries them verbatim even though the design file repeats them:

- The **authoritative feature IDs** and §2.X contract numbers introduced (e.g. "S-20, S-21, …; §2.28, §2.29").
- **Standard-form `- **X-N**` bullets** for `^- \*\*[A-Z]-` grep traversal compatibility.
- The **§25 fidelity-audit vocabulary additions** (the auditor reads the whole architecture file).
- The **anti-drift exact pending-folder-name map**.
- The **§20 sequencing** note.

The full rationale, mapping tables, spec sketches, and ticket plan stay in the linked design file.

## Ratification status convention

A freshly-appended reference block may carry `**Status:** PROPOSED` until the operator approves. PROPOSED
vs ratified is a one-line status field inside the appended block — still additive; promotion to ratified
is another additive edit of that one line, never a rewrite of prior sections.

## Checklist before committing any constitution touch

- [ ] Detail content written to a new file (not inline-expanded into the constitution).
- [ ] Reference block appended at END of the canonical doc; new section number does not collide.
- [ ] IDs, standard-form bullets, §25 vocab, anti-drift folder map, §20 sequencing present inline.
- [ ] `git diff --numstat <constitution>` shows `<adds>  0  <file>` (zero deletions).
- [ ] `git diff <constitution> | grep -c '^-[^-]'` returns `0` (no altered/removed content lines).
- [ ] Linked design file committed in the same CL.

Persisted 2026-06-08 after the operator directed: "write new files and simply append references to them in
the original constitution without deleting or altering any existing content of it … persist this pattern
for all new and ongoing work."
