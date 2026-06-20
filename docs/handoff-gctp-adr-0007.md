# Handoff — GCTP: adopt the latest CTP (ADR-0007 / PROPOSAL-003 line)

**Audience:** the GCTP (`grok-claude-tdd-pro`) session that consumes `claude-tdd-pro` as a pinned plugin.
**Purpose:** bump the CTP pin and adopt the YAML/JSON/MD rule corpora + prose-as-code + write/generation-time enforcement that landed for PROPOSAL-003.

---

## 1. TL;DR — the pin bump

| field | value |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` |
| Branch | `main` |
| **Pin to commit** | **`39903dafd3ed7c207d45a807071bd89dc0c55c29`** |
| Plugin version | `0.3.0` (unchanged; additive §28.24–§28.27 amendments) |
| Landed | CL-484 → CL-487 (ADR-0007) |
| CTP self-suite at pin | 4407/4407 green |

Everything below is **additive**. No existing CTP contract signature changed, so the
bump is non-breaking; adopting the *new* surface is opt-in per item.

---

## 2. Boundary (unchanged)

CTP does **not** edit GCTP and GCTP does **not** edit CTP. The only contract surface that
moves between them is:

1. **`active.json`** — the rule catalog GCTP regenerates from CTP's `generated-code-quality-standards/` tree.
2. **`rubric/detectors/`** — the executable detectors.
3. **`rubric/enforce.sh`** (tree) and **`rubric/enforce-file.sh`** (single file) — the enforcement entrypoints.

Adopt by re-syncing the pinned plugin tree; do not reach across the boundary.

---

## 3. What changed since the prior pin (the contract-surface delta)

### 3.1 New rule shape field (additive, schema-validated)
- `applies_to_prose: boolean` (default `false`) + `applies_to_prose_kinds: string[]` (default `["architecture","adr"]`) in `schemas/rubric-rule.schema.json`. `additionalProperties` stays `false`; the fields are whitelisted. **GCTP's `active.json` generator must pass these through** (they may already, if it copies unknown fields verbatim).

### 3.2 New detectors in `rubric/detectors/` (ship these with the synced tree)
- **`prose-judge.sh`** — semantic-projection detector (the §11 centerpiece). Any rule body + any prose section → `violates`/`compatible`/`abstain`; keyword tier (deterministic) → `LLM_JUDGE=1` tier → `not_enforced` fallback; SARIF 2.1.0; caches by `(rule_body, section)` hash.
- **`md-structure.sh`** — deterministic Markdown lint (MD040/MD025), dependency-free.
- **`json-syntax.sh`** — RFC 8259 well-formedness via node (dependency-free).
- **`yaml-syntax.sh`** — YAML 1.2.2 well-formedness via ruby.
- **`cloud-guidance-rule.sh`** — now (a) merges a **second manifest** and (b) its `--paths` accepts a single absolute file path.

### 3.3 New detector manifest (ship alongside `cloud-guidance-rules.json`)
- **`rubric/detectors/config-guidance-rules.json`** — 68 rules. `cloud-guidance-rule.sh` and `enforce.sh` read both manifests. If GCTP vendors the detector manifests, it must vendor this new file too.

### 3.4 New / expanded catalog (what `active.json` will hold)
- **118 total rules** across **44 namespaces** (was ~48 rules). New namespaces: `yaml json k8s helm compose gha glci azdo circleci bbp jenkins ansible cfn oas gitops observability mesh iac-linter jsonschema iam sbom sarif jwt arch md`.
- High-leverage clusters: **k8s** (privileged/hostNetwork/runAsNonRoot/…), **iam** (wildcard action/resource/principal/`*:*`), **jwt** (RFC 8725 `alg:none`), **gha** (pinned actions, `pull_request_target`), plus json/yaml/md well-formedness.
- A curated set carries `applies_to_prose: true` (the unrestricted-ingress rules + iam/jwt/k8s/gha) so they fire on **architecture prose**, not only code.

### 3.5 New enforcement entrypoint (opt-in)
- **`rubric/enforce-file.sh --file <path>`** — the single-file projection of `enforce.sh`. Discovers every applicable rule for one file, runs its detector, and runs `applies_to_prose` rules through `prose-judge.sh` on `.md`. **Severity/mode gating:** blocks (exit 1) only on P0/P1 **forbid/wrapper/prose** violations; `require`-absent is advisory (never a false-positive block). Exit `0` green/advisory · `1` blocking · `3` not_enforced · `2` usage.
- `rubric/enforce.sh` (the existing §28.17 tree contract) is **unchanged in signature** — 4-state `pass|fail|not_applicable|not_enforced`, exit `0/1/3/2`.

### 3.6 Output bus
- All new detectors emit **SARIF 2.1.0** under `--json`.

---

## 4. GCTP adoption steps

1. **Bump the CTP pin** to `39903dafd3ed7c207d45a807071bd89dc0c55c29` in whatever GCTP uses to pin the plugin (lockfile / submodule SHA / `sync-plugin.sh` ref).
2. **Re-sync the plugin tree** (GCTP's existing `sync-plugin.sh --ensure` or equivalent) so the new `generated-code-quality-standards/<ns>/`, `rubric/detectors/*.sh`, and `rubric/detectors/config-guidance-rules.json` land.
3. **Regenerate `active.json`** from the synced catalog (now 118 rules). Ensure the generator copies the new `applies_to_prose` / `applies_to_prose_kinds` fields through. **CTP-D-7: bump `active.json` `schema_version`** at this point (consumer-side — CTP has no `active.json`).
4. **(Opt-in) wire the new enforcement surface** into GCTP's flows:
   - For tree checks: keep calling `rubric/enforce.sh --root <app> --rule <id>` (unchanged).
   - For per-file / write-time / generation-time checks: call `rubric/enforce-file.sh --file <path>` and treat exit 1 as a blocking violation (P0/P1), exit 3 as `not_enforced`.
   - If GCTP loads CTP's `hooks/hooks.json`, the PostToolUse `enforce-standards-on-save.sh` hook will already enforce config/markup/IaC + prose-as-code at write time; otherwise GCTP can invoke `enforce-file.sh` from its own write/generation hooks.
5. **Refresh:** the new sources auto-enroll via CTP's `standards/initial-refresh.sh` (header-walk of `generated-code-quality-standards/*/*.yaml`) — no GCTP action beyond running the synced `initial-refresh.sh` (already wired into CTP's SessionStart + install).

---

## 5. Post-pin verification (GCTP-side smoke checks)

```bash
# 1. catalog reaches active.json (expect 118 rules across 44 namespaces)
#    -> GCTP's active.json regen count

# 2. a forbidden IaC pattern is caught on a tree
printf 'spec:\n  containers:\n  - securityContext:\n      privileged: true\n' > /tmp/pod.yaml
bash <ctp>/rubric/enforce.sh --root /tmp --rule g-k8s-no-privileged-container   # -> fail / exit 1

# 3. prose-as-code: an ADR proposing a forbidden design red-flags before code exists
mkdir -p /tmp/adr && printf '# 0001\n\n## Decision\n\nLeave ingress unrestricted (0.0.0.0/0).\n' > /tmp/adr/0001.md
bash <ctp>/rubric/enforce-file.sh --file /tmp/adr/0001.md   # -> rule=g-aws-no-unrestricted-ingress verdict=fail, exit 1

# 4. a clean file passes; a generic config.yaml is advisory (no false-positive block)
```

Expected: (2) and (3) exit 1 (blocking); a clean doc exits 0.

---

## 6. References (in the pinned CTP tree)

- ADR: `docs/adr/0007-yaml-json-md-corpora-and-prose-judge.md`
- Architecture amendments (append-only): `docs/architecture-v1.9.md` **§28.24** (substrate), **§28.25** (corpora), **§28.26** (prose-as-code activation), **§28.27** (write/generation-time enforcement)
- Design: `docs/design/v1.19-prose-as-code-and-corpora.md`
- Source manifest (155 sources): `docs/standards-source-manifest.md`
- Enforcement contract: `rubric/enforce.sh`, `rubric/enforce-file.sh`

---

## 7. One open follow-on (non-blocking)

CTP's daily refresh (`standards/auto-refresh-daily.sh`) resolves cadence from the fixed S-1
catalog and defaults header-sourced namespaces (old and new) to **daily** — so a header
declaring `monthly` (e.g. `md`) is over-refreshed, never under-refreshed. Sources still
refresh; only exact cadence fidelity is pending. Safe to adopt now; CTP can land the
cadence-lookup enhancement separately.
