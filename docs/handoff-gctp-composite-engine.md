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
| **Pin to** | **`230e99d864bfba0b54ea9168ecc825a65bbecf70`** |
| Plugin version | `0.3.0` (unchanged; additive §28.28–§28.39 amendments) |
| Landed | ADR-0008 + ADR-0009, fully built (composite engine + auto-classification pipeline) |
| CTP self-suite at pin | 4510/4510 green |

Everything is **additive**. No existing CTP contract signature changed, so the bump is
non-breaking; adopting each *new* surface is opt-in — **except** the one consumer-visible
semantics change in §4 (hard-require), which needs a paired GCTP ADR before you rely on it.

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

## 5. GCTP adoption steps

1. **Bump the CTP pin** to `230e99d…` in whatever GCTP uses (lockfile / submodule SHA / `sync-plugin.sh`).
2. **Re-sync the plugin tree** so the new `vendor/`, `rubric/`, `commands/`, `standards/`, and the
   migrated `generated-code-quality-standards/` (rules now carry `applies_to`/`enforced_by`) land.
3. **Regenerate `active.json`** (118 rules, now 4-axis-tagged + routed); pass the new fields through;
   **bump `schema_version`** (CTP-D-7, consumer-side).
4. **Toolchain:** CTP's installer provisions the FOSS tools at install time and GCTP inherits them by
   consuming CTP. If GCTP installs separately, run `rubric/runners/install-toolchain.sh`
   (`--permissive-only` for a zero-copyleft footprint; see `COMMERCIAL-USE.md`).
5. **Wire the new enforcement surface** (opt-in):
   - **Write-time, per file:** `rubric/composite-dispatch.sh --file <path>` (routed FOSS tools) and/or
     `rubric/enforce-file.sh --file <path>` (in-repo rules + prose + bundle). If GCTP loads CTP's
     `hooks/hooks.json`, the PostToolUse `enforce-standards-on-save.sh` already runs all three stages.
   - **Audit-time, whole tree:** `rubric/composite-audit.sh --root <app>` (in-repo rules + routed
     tools + bundle; exit 0 green / 1 red / 3 incomplete).
   - **Tree, in-repo rules only (unchanged):** `rubric/enforce.sh --root <app> --rule <id>`.
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

- ADRs: `docs/adr/0008-composite-engine-and-4-axis-canonical-vocabulary.md`,
  `docs/adr/0009-auto-classification-and-rule-drafting-pipeline.md` (and `0007` for the prose line).
- Architecture amendments (append-only): `docs/architecture-v1.9.md` **§28.28–§28.39**.
- Commercial policy: `COMMERCIAL-USE.md`. Source manifest: `docs/standards-source-manifest.md`.
- Prior handoff (ADR-0007 line): `docs/handoff-gctp-adr-0007.md`.

---

## 8. Boundary (unchanged)

CTP does **not** edit GCTP and GCTP does **not** edit CTP. The only surface that moves is
`active.json` + `rubric/detectors/` + the enforcement entrypoints. The paired GCTP-side ADRs
(**0068** composite-engine wiring, **0069** auto-classification wiring) are GCTP's to author —
ADR-0068 is the gate for adopting the §4 hard-require semantics.
