# Pending-spec content fidelity — discipline & checklist

**Status:** v1.9.2 (architecture amendment §25). Read at the start of every CL that promotes pending specs.

**Purpose:** close the drift class where a `evals/pending/<phase>/<feature-id>-<label>/` folder name correctly maps to the architecture but the **spec body** asserts behavior against vocabulary not in the architecture text for that feature. The CL-08/09/10 drift catalog defended at folder granularity; this defends at spec-content granularity.

## The discovered failure mode (CL-273 worked example)

**Folder:** `evals/pending/CC/2-6-standards-source/` (correctly maps to architecture §2.6 Standards source contract).

**Architecture §2.6 specifies the operator-facing registry as:**

```yaml
- id: google-tsguide
  name: "Google TypeScript Style Guide"
  url: https://google.github.io/styleguide/tsguide.html
  tier: 1
  applies_to: [typescript, react]
  fetch_frequency: daily
```

Plus a defined plugin-internal field list: `class, authority_tier, fragility_tier, fragility_strategy, fetcher, identifier_pattern, license_note, origin, added_by, added_at`.

**What the pending specs actually asserted:** a YAML *map* (`{src-1: {...}}`) at top level with fields `publisher` (arch uses `name`), `license` (arch uses `license_note`), `last_verified`, `archive_url`, `etag`, `derivative_rules` — none of which appear in §2.6. The folder name was right; the vocabulary inside was invented.

**Why it slipped past existing guards:**

- Step 0 (pre-flight architecture extraction): satisfied at the folder-ID level. Folder `2-6-...` traces to §2.6 verbatim.
- Step 2 (self-audit "architecture fidelity"): same — checks folder names, not spec bodies.
- Drift-catalog items 1-5: all about folder/feature granularity, none about field-level vocabulary inside specs.
- CLI-flag-invention discipline: covers invocation surface (`--foo`), not data schema vocabulary.

The whole audit machinery assumed the model writes specs and substrate in the same CL. Pending specs that pre-existed on disk (authored by an earlier session or batch) were never re-audited at promotion time.

## What gets audited

Per `rubric/detectors/audit-pending-spec-fidelity.sh`, the audited vocabulary surface is:

1. **Field names** referenced in setup arrays or command assertions. Pattern: `<word>:` inside YAML/JSON strings.
2. **YAML/JSON document shape** at the top level (array of objects vs map of objects vs single object).
3. **Output format keys** the spec greps for in stderr/stdout.
4. **Enum values** the spec writes as inputs or expects in outputs.
5. **Substrate paths** the spec invokes via `$CLAUDE_PLUGIN_ROOT/<path>`.

**Exempt** (not flagged by the auditor):

- CLI flag names (`--foo`, `-b`) — these are test-affordance per the existing CLI-flag-invention discipline. Disclosed separately in commit bodies.
- Test fixture content that is not meant to be schema-conformant (e.g., the `not-a-hash` string in §2.1 specs that intentionally feeds invalid data).
- Common English words appearing in spec NAMES (`accepts`, `rejects`, `validates`, `emits`).

## The pre-promotion checklist

Run this BEFORE invoking `probe-feature` or `promote-pending` for any feature whose specs you did not write yourself in this CL.

- [ ] Read the architecture section for the feature ID. Quote it in your scratch context.
- [ ] Run `bash rubric/detectors/audit-pending-spec-fidelity.sh --pending evals/pending/<phase>/<folder>/ --arch docs/architecture-v1.9.md --section "<§X>"`.
- [ ] If exit 0: proceed to probe/promote.
- [ ] If exit 1: triage each `unknown_vocab=...` line to one of three resolution paths:
  - **Spec rewrite** — change the spec to use arch-spec'd vocabulary. Most common.
  - **Architecture amendment** — open a separate governance CL to extend the architecture. Use when the vocabulary represents a genuine missing concept the architecture should formally adopt.
  - **Misfiled relocation** — move to `evals/pending/_misfiled/<feature-id>/`. Use when the spec is intelligible but does not belong under this feature.
- [ ] In the commit body, list each resolution choice under a "Spec patches in this CL (architecture-fidelity corrections):" section. Mirrors how CL-273 disclosed.

## Common patterns and their resolutions

| Pattern in pending spec | Likely resolution |
|---|---|
| Different field name with same role (`publisher` vs `name`) | Spec rewrite to arch name |
| Different YAML shape at top (`{<id>: {...}}` vs `[- id: ...]`) | Spec rewrite to arch shape |
| Fields not in arch but clearly part of the concept (`last_verified`, `etag`) | Architecture amendment if the concept is real |
| Fields that contradict the arch (e.g., spec tests "license" enum but arch says no license enum exists) | Misfiled relocation |
| Substrate path not in arch (`fetch-source.sh`) | Substrate path is invocation surface — check if `--<flag>`-style affordance; otherwise needs architecture amendment for the script's role |

## Why this is governance, not feature

The §2.25 contract and §25 amendment introduce no new feature IDs and ship no new spec-tested behavior. The detector script is substrate, but its specs (when authored) will live under whatever §X covers detectors generally — not under §25. This amendment is workflow discipline that prevents wrong code from being authored, not new code that does new things.

## Reference

- Architecture §2.25 — Pending-spec content fidelity contract
- Architecture §25 — v1.9.2 amendment text
- CLAUDE.md — Step 0.5 (workflow loop), drift mechanism #6
- `rubric/detectors/audit-pending-spec-fidelity.sh` — substrate
- CL-273 — originating CL; 8/10 specs in `CC/2-6-standards-source/` rewritten under path 1.
