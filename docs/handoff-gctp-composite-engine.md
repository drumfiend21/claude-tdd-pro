# Handoff — GCTP: adopt the latest CTP (composite-engine line, ADR-0008 + ADR-0009)

**Audience:** the GCTP (`grok-claude-tdd-pro`) development session that consumes `claude-tdd-pro`
as a pinned plugin.
**Purpose:** bump the CTP pin from the ADR-0007 line to the composite-engine line and adopt the
4-axis canonical vocabulary + FOSS-tool routing + write/audit-time enforcement + the
commercial-license posture.

---

## 1. TL;DR — the pin bump

| field | value |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` |
| Branch | `main` |
| **Pin from** | `39903da` (ADR-0007 / PROPOSAL-003 line) |
| **Pin to** | **current `main` HEAD** (composite-engine + consumer-compatibility line; ≥ `eaa70d2`) |
| Plugin version | `0.3.0` (unchanged; additive §28.28–§28.41 amendments) |
| Landed | ADR-0008 + ADR-0009 **fully built**, + the §28.40 Consumer Compatibility Contract (epoch tags) |
| CTP self-suite at pin | 4500+ green |

Everything is **additive at the schema layer**. No existing CTP CLI signature changed. But adopting
this line is *not* free at your **enforcement-STATE** layer — read §4a (Consumer Compatibility
Contract) before re-baselining, and §4b (enforce standards like CTP). The two consumer-visible
items that need a paired GCTP ADR-0068 are the **hard-require** verdict (§4) and the **epoch-gated
floors** (§4a).

### What's new since the previous pin (`230e99d`)
- **Recent standards/rules work:** the full 118-rule corpus is migrated to the 4-axis vocabulary
  with `enforced_by[]` routing **and** every rule now carries an **`introduced_in` epoch tag**
  (§28.40). New standing gates: `audit-applies-to-parity.sh` (no enforcement dropped),
  `audit-commercial-license.sh` (sellable), `audit-consumer-compatibility.sh` (epoch + absent-default).
- **Consumer Compatibility Contract** (`docs/consumer-compatibility-contract.md`) +
  `schemas/field-semantics.json` (absent-default registry) — the metadata you need for epoch-aware,
  non-breaking adoption (§4a).

---

## 2. What this line adds (one paragraph)

CTP now scrapes a standards URL → tags each rule with the **industry 4-axis canonical vocabulary**
(GitHub Linguist languages · IaC-scanner dialect consensus · PURL · Kubernetes GVK) → routes each
rule by kind to the **proper FOSS tool** (checkov, eslint, semgrep, markdownlint, …) → and enforces
it on the **writing and auditing** of every file. The full 118-rule corpus is migrated to this
vocabulary with enforcement parity preserved, the FOSS toolchain installs at install time, and the
whole thing is gated as **commercially sellable** (permissive bundled data; copyleft tools are
invoke-only, never shipped).

---

## 3. Contract-surface delta (what GCTP must vendor/regenerate)

### 3.1 `active.json` rule shape — additive fields
Each rule now carries (the §2.1 schema is extended `oneOf`/additive — `additionalProperties` stays false):
- **`applies_to`** — either the legacy string array OR the **4-axis object**: `linguist_aliases[]`,
  `iac_dialects[]`, `purl_uses[]`, `k8s_gvks[]`.
- **`enforced_by[]`** — ordered tool/bundle bindings. Entry 0 is the rule's original detector
  (`required: true`) — its existing enforcement, preserved (parity). Following entries are the
  routed FOSS tools + `{ bundle: architectural-content }` when `applies_to_prose: true`.
- **`applies_to_prose` / `applies_to_prose_kinds`** (already present from the ADR-0007 line).

**GCTP action:** regenerate `active.json` from the synced catalog; ensure the generator passes
`applies_to` / `enforced_by` through verbatim. **Bump `active.json` `schema_version`.**

### 3.2 New bundled data (permissive — safe to redistribute)
- `vendor/canonical-vocabulary/{linguist-languages,purl-types,k8s-gvks,iac-dialects}.json` (MIT/Apache-2.0)
  + `provenance.json` + `resolve.sh` + `refresh-vocabulary.sh`.
- `standards/kind-to-tool-routing.yaml` (kind → FOSS tool, with per-tool license).
- `standards/namespace-axis-binding.yaml` (namespace → 4-axis binding, drives the migration).
- `rubric/runners/toolchain.json` (the FOSS toolchain manifest; GPL/LGPL flagged `invoke_only`).

### 3.3 New detectors / runners / entrypoints in `rubric/`
- **Engine:** `rubric/composite-dispatch.sh` (single file → resolve → route → run → SARIF verdict),
  `rubric/composite-audit.sh` (whole-tree audit gate), `rubric/sarif-aggregate.sh` (SARIF 2.1.0 bus),
  `rubric/enforce-file.sh` (per-file in-repo rules + prose).
- **Runners:** `rubric/runners/run-tool.sh` (per-tool adapters + missing-tool policy),
  `rubric/runners/run-bundle.sh` (architectural-content bundle), `rubric/runners/install-toolchain.sh`.
- **Gates:** `rubric/detectors/audit-applies-to-parity.sh` (no enforcement dropped),
  `rubric/detectors/audit-commercial-license.sh` (sellable-with-no-conflict).
- **Pipeline (ADR-0009):** `commands/{extract-rules-from-url,classify-rule,route-rule,draft-custom-rule,review-queue}.sh`.
- `rubric/detectors/llm-judge.sh` gained `--text` (the P-8 fix; `prose-judge.sh` interface unchanged).

### 3.4 Existing entrypoints — unchanged signature
`rubric/enforce.sh` (tree, in-repo rules, §28.17 4-state) is **unchanged**. Keep calling it as-is.

---

## 4. The one consumer-visible semantics change (needs paired GCTP ADR-0068)

The §28.28 operator policy: a tool declared **`required`** in a rule's `enforced_by[]` **hard-fails
(blocks)** when its binary is absent — distinct from the `not_enforced` advisory state used for
optional tools. Because this changes the verdict a consumer reads from the engine, **GCTP must
reflect it in its paired ADR-0068 before relying on the routed-tool verdicts.** Until then, GCTP can
keep consuming `enforce.sh`'s 4-state verdict unchanged.

---

## 4a. Consumer Compatibility Contract — epoch-aware adoption (READ before re-baselining)

The previous handoff was consumer-compatible at the *CLI-signature* layer but **not at the
enforcement-STATE layer**: additive rule fields (e.g. `applies_to_prose`) instantly add floor
requirements that red a consumer's legacy pin-keyed state (completed-ticket records, baselines,
smoke fixtures). CTP now ships the **Consumer Compatibility Contract**
([`docs/consumer-compatibility-contract.md`](consumer-compatibility-contract.md)) to make that
asymmetry explicit and gate-able:

- **Every rule now carries `introduced_in`** (epoch tag; existing rules = `baseline`). **Gate your
  floors by epoch:** a floor requirement applies only to tickets/content whose issue-epoch ≥ the
  rule's `introduced_in`. This is the single fix for the "9 prose rules → 205 reds on legacy req.json"
  pattern — grandfather pre-epoch tickets instead of mass-rewriting.
- **`schemas/field-semantics.json`** declares the `absent_default` for every enforcement-relevant
  optional field (`applies_to_prose` absent ⇒ false; `enforced_by` absent ⇒ `[detector required]`;
  etc.). Make your dual-read shim read these — never derive a floor from a field whose absent-default
  makes the rule inapplicable.
- **`not_enforced` ≠ red.** A `required` tool absent hard-fails; an optional/absent tool is
  `not_enforced` (advisory). If your standards-enforced gate treats `not_enforced` as red, read the
  `required` flag (see §4).
- **Pin-keyed baselines are the pin-bump CL's scope.** Re-baseline `cross-references-baseline.txt`,
  `hook-security-baseline.txt`, the plugin-surface registry, etc. as part of the bump CL, with the
  diff visible in your ADR-0068/0069. The plugin-tree additions to declare this pin are listed in the
  retro-filled `consumer_compatibility` block in the contract doc (`vendor/`, `COMMERCIAL-USE.md`,
  `schemas/field-semantics.json`).
- **Smoke fixtures:** no clean toy file newly fails any universal rule at this pin (asserted in the
  contract's `smoke_fixture_stable`); the new detectors only fire on real violations.

The filled `consumer_compatibility:` block for this line (new rule classes, detector behavior
changes, plugin-tree additions, smoke-fixture-stable assertion) is in the contract doc. Every future
rule-schema-touching CTP ADR will carry one — `audit-consumer-compatibility.sh` fails CTP's build
if it doesn't.

## 4b. GCTP enforces standards like CTP (the core of this handoff)

GCTP should not merely *consume* CTP's rules — it should **enforce them the same way CTP enforces
them on itself**, on two surfaces: **(A) GCTP's own repository**, and **(B) every application GCTP
builds**. CTP enforces on itself through three mechanisms; GCTP wires the same three using the same
engine entrypoints (no re-implementation):

| CTP self-enforcement mechanism | What GCTP wires (same scripts) |
|---|---|
| **Write-time** — `hooks.json` PostToolUse `enforce-standards-on-save.sh` runs on every Edit/Write | Load CTP's `hooks/hooks.json` in the GCTP plugin set **or** call `rubric/enforce-file.sh --file <path>` + `rubric/composite-dispatch.sh --file <path>` from GCTP's own write hook. Blocks a violating write inline. |
| **Audit-time** — whole-tree conformance gate | `rubric/composite-audit.sh --root <tree>` (in-repo rules **+** routed FOSS tools **+** prose bundle; exit 0 green / 1 red / 3 incomplete). Run in GCTP CI on the GCTP repo, and as the harness's delivery gate on each generated app tree. |
| **CI audit gates** — standing invariants | Run CTP's gates in GCTP CI: `audit-commercial-license.sh` (keep GCTP sellable), `audit-consumer-compatibility.sh`, and your own parity/coverage gates. |

### A. Enforce on GCTP's own repo
1. Add CTP's PostToolUse enforcement to GCTP's hook set (load `hooks/hooks.json`, or mirror the one
   line that calls `enforce-standards-on-save.sh`). Now every file GCTP writes is held to the same
   standards CTP holds itself to — code via the routed tools, prose/ADRs via the architectural-content
   bundle + prose-judge, IaC via checkov/etc.
2. In GCTP CI: `bash <ctp>/rubric/composite-audit.sh --root .` — fail the build on `red`. This is the
   GCTP analogue of CTP's own green-suite invariant.

### B. Enforce on every app GCTP builds (the harness's job)
1. **During generation (write-time):** as the harness writes app files, run
   `rubric/enforce-file.sh --file <path>` (+ `composite-dispatch.sh` for the routed tools) so violating
   content is caught as it is produced — exactly the "enforcement on the writing of all content" the
   composite engine provides.
2. **At delivery (audit-time):** gate ticket/feature completion on
   `bash <ctp>/rubric/composite-audit.sh --root <generated-app-tree>` returning green. A `red` means the
   generated app violates a standard; an `incomplete` means a required tool was absent (a broken
   toolchain install — see §4 hard-require). Do not mark a ticket done on a non-green audit.
3. **Same rule set, same verdict:** the rules come from the synced `active.json` (4-axis-tagged,
   `enforced_by`-routed); the verdict is the §28.17 4-state. GCTP enforces *identically* to CTP because
   it runs the *same* engine over the *same* catalog.

### Epoch-aware gating (so this is not breaking — see §4a)
When GCTP derives a *floor* (e.g. "every .md must satisfy every `applies_to_prose` rule"), gate it by
the rule's `introduced_in` epoch: enforce the floor only on content/tickets issued at or after the
rule's epoch. Read `schemas/field-semantics.json` for each field's `absent_default`. This lets GCTP
adopt the full enforcement posture **without** retroactively red-flagging its legacy state.

## 5. GCTP adoption steps

1. **Bump the CTP pin** to `230e99d…` in whatever GCTP uses (lockfile / submodule SHA / `sync-plugin.sh`).
2. **Re-sync the plugin tree** so the new `vendor/`, `rubric/`, `commands/`, `standards/`, and the
   migrated `generated-code-quality-standards/` (rules now carry `applies_to`/`enforced_by`) land.
3. **Regenerate `active.json`** (118 rules, now 4-axis-tagged + routed); pass the new fields through;
   **bump `schema_version`** (CTP-D-7, consumer-side).
4. **Toolchain:** CTP's installer provisions the FOSS tools at install time and GCTP inherits them by
   consuming CTP. If GCTP installs separately, run `rubric/runners/install-toolchain.sh`
   (`--permissive-only` for a zero-copyleft footprint; see `COMMERCIAL-USE.md`).
5. **Enforce standards like CTP — wire BOTH surfaces (see §4b, the core step):**
   - **GCTP's own repo:** add CTP's PostToolUse `enforce-standards-on-save.sh` to GCTP's hook set
     (write-time), and run `rubric/composite-audit.sh --root .` in GCTP CI (gate on green).
   - **Every app GCTP builds:** run `rubric/enforce-file.sh --file <path>` during generation and gate
     ticket/feature completion on `rubric/composite-audit.sh --root <generated-app>` returning green.
   - Entrypoints: `composite-dispatch.sh` (routed FOSS tools, per file), `enforce-file.sh` (in-repo
     rules + prose + bundle, per file), `composite-audit.sh` (comprehensive whole-tree), `enforce.sh`
     (tree, in-repo rules, unchanged signature). Gate floors by `introduced_in` epoch (§4a).
6. **Commercial-license gate (recommended in GCTP CI):** `rubric/detectors/audit-commercial-license.sh`
   fails the build on any bundled non-permissive license — keep GCTP sellable too.
7. **Refresh:** `standards/initial-refresh.sh` enrolls all sources + the vocabulary mirrors for
   regular re-scrape (already wired into SessionStart + install).

---

## 6. Post-pin verification (GCTP-side smoke checks)

```bash
CTP=<ctp-plugin-root>

# 1. corpus is 4-axis-tagged + routable + parity-preserved (no enforcement dropped)
bash $CTP/rubric/detectors/audit-applies-to-parity.sh    # -> status=green rules=118 parity_fail=0 unrouted=0

# 2. commercially sellable (bundled permissive; copyleft tools invoke-only)
bash $CTP/rubric/detectors/audit-commercial-license.sh   # -> commercial-license status=green violations=0

# 3. a rule routes by kind AND enforces on write (privileged pod blocked)
printf 'apiVersion: v1\nkind: Pod\nspec:\n  containers:\n  - securityContext:\n      privileged: true\n' > /tmp/pod.yaml
bash $CTP/rubric/enforce-file.sh --file /tmp/pod.yaml     # -> rule=g-k8s-no-privileged-container verdict=fail, exit 1

# 4. whole-tree audit flags violations and passes a clean tree
bash $CTP/rubric/composite-audit.sh --root <repo-with-violations>   # -> status=red, exit 1
```

The 10 end-to-end integration tests live in CTP at `evals/specs/e2e-01..10` (`bash evals/runner.sh e2e`)
and exercise the full chain GCTP relies on.

---

## 7. References (in the pinned CTP tree)

- ADRs (updated 2026-06-23 with a **Consumer compatibility contract** + **Build status**):
  `docs/adr/0008-composite-engine-and-4-axis-canonical-vocabulary.md`,
  `docs/adr/0009-auto-classification-and-rule-drafting-pipeline.md` (and `0007` for the prose line).
- **Consumer Compatibility Contract:** `docs/consumer-compatibility-contract.md` +
  `schemas/field-semantics.json` (absent-default registry). Gate: `rubric/detectors/audit-consumer-compatibility.sh`.
- Architecture amendments (append-only): `docs/architecture-v1.9.md` **§28.28–§28.41**.
- Commercial policy: `COMMERCIAL-USE.md`. Source manifest: `docs/standards-source-manifest.md`.
- Prior handoff (ADR-0007 line): `docs/handoff-gctp-adr-0007.md`.

---

## 8. Boundary (unchanged)

CTP does **not** edit GCTP and GCTP does **not** edit CTP. The only surface that moves is
`active.json` + `rubric/detectors/` + the enforcement entrypoints. The paired GCTP-side ADRs
(**0068** composite-engine wiring, **0069** auto-classification wiring) are GCTP's to author —
ADR-0068 is the gate for adopting the §4 hard-require semantics.

---

## 9. v1.18 capabilities to adopt (§28.56–§28.68) — guaranteed enforcement + two co-equal build flows

This wave makes enforcement **total** and the build **two-flow**. GCTP wires the same entrypoints; the
new behavior is in them. Each item cites its architecture section + the verifying spec family.

**Enforcement is now guaranteed — no rule unenforced, on any file type, at every phase:**
- **§28.56 native fallback** — when a routed 3rd-party tool can't be found, `composite-dispatch.sh` falls
  back to native enforcement; `--required` tools still hard-fail (the §4 / ADR-0068 semantics).
  (`cl524-fallback-*`)
- **§28.57 universal native enforcer** — the native enforcer can enforce ANY SE/architecture rule on ANY
  file type via `prose-judge.sh --body/--forbid` (a scraped tool-only rule with no bespoke detector is
  still enforced). (`cl525-universal-*`)
- **§28.60 govern-before-write** — `hooks/scripts/enforce-standards-pre-write.sh` (PreToolUse) evaluates
  proposed content IN MEMORY and denies a violating write before save. (`cl528-prewrite-*`)
- **§28.68 both-paths pre-write** — both rule sets (IaC + full-stack) govern in memory before write:
  `enforce-file.sh --include-app-code --single-file-gate` natively enforces the full-stack set on app
  code (any language, derived from `linguist_aliases`); tree-context rules (coverage) are audit-time
  only. So enforcement holds at **design → in-memory-before-write → write → audit**. (`cl536-bothpaths-*`)

**The single config surface is complete and persisted:**
- **§28.58 universal config object** — every rule has a config object with options for its tool; all 9
  3rd-party tools project their proprietary options from the single config (checkov via file,
  semgrep/trivy via `render.method:cli`); `commands/config-sync.sh --check` is the nothing-missing gate
  (`needs_mapping=0` over the corpus). (`cl526-config-*`)
- **§28.59 persisted, cached options-view** — `config-sync --persist` writes `standards/config-options-view.yaml`,
  re-materializing only rules whose source/mapping changed (cache-if-no-change). (`cl527-view-*`)

**Two co-equal, coupled, language-agnostic build flows:**
- **§28.62/§28.67 co-design** — `commands/codesign-build.sh` derives a full distributed system (FE, BE/REST,
  message-queue, **SQL + NoSQL**, IaC) from one decision; app units declare required infra and infra
  units declare served app (reconciled). Platform-native (aws/gcp/azure). (`cl530-codesign-*`, `cl534-bothflows-*`)
- **§28.63 development-path tagging** — `commands/classify-path.sh` tags every rule `iac` / `fullstack` /
  `both` (cross-cutting rules → both), so the two rule sets are explicit and complete; every rule pathed.
  (`cl531-path-*`)
- **§28.64 language/framework agnosticism** — no Node/React preference; the stack is `toolchain-selected`
  (any language honored via `--toolchain`); the four-axis registry admits all languages. (`cl532-agnostic-*`)

**Verification GCTP can mirror:** 100% file coverage (`coverage-gap.js` → 0 uncovered, §28.65); 50
both-flow/full-flow integration tests; full distributed-system assertions across 20 domains × 3 clouds ×
10 agnostic toolchains. Adopt these by re-vendoring the moved surface (`commands/codesign-build.sh`,
`commands/classify-path.sh`, `commands/config-sync.sh`, `hooks/scripts/enforce-standards-pre-write.sh`,
the `enforce-file.sh` flags) and wiring the PreToolUse govern-before-write hook alongside the existing
write-time/audit-time entrypoints. Epoch-aware adoption per §4a still applies. **No CTP→GCTP edit; GCTP
authors ADR-0068/0069.**
