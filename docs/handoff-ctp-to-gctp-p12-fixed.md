# CTP → GCTP handoff — P-12 BUILT: full-surface requirements intake (§30 + §30.1 + §30.2)

**Written:** 2026-07-04 · **Updated:** 2026-07-05 (adds §30.1 design-consumption + §30.2 coverage; re-pin bumped to `43ea692`)
**From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** GCTP inbound proposal P-12 (full-surface intake) + KATA readiness audit / TICKET-114..116
**Status:** ✅ ASSESSED · CONFIRMED · BUILT (additive) · TESTED · MERGED TO `main` · both loop-halves + coverage closed
**Ask fulfilled:** new feature + contract + section via the append-only amendment — **at CTP-correct coordinates** (see §1) — plus the design-consumption close-out (§30.1) and the IaC-coverage + transparency close-out (§30.2).

## 0. TL;DR

P-12 is correct: CTP's **output** was full-surface (§29/P-11) but its **intake** was a fixed universal-9
questionnaire, so most namespaces grounded from defaults, not stated facts. Fixed additively with **S-57
`commands/full-surface-intake.sh`** + contract **§2.35** + section **§30**: a workload classifier + per-
namespace probe groups produce a **v1.1 `business-profile.json`** that is a strict additive superset of
v1.0. Two follow-ons close the loop: **§30.1** (CL-547) makes the design engines *consume* the committed
probes (they steer grounded concerns + the recommended pick); **§30.2** (CL-548) makes cloud classification
*precise* (an AWS-only workload is not probed for Azure/GCP), adds `azure`/`gcp`/`cfn` probe coverage, and
adds an `unprobed_in_scope` transparency marker so no in-scope namespace is ever silently unprobed.
**Re-pin CTP → `43ea692` and execute TICKET-114..116.**

## CL / pin chain (adopt in order)

| CL | Section | What | Pin after |
|---|---|---|---|
| CL-546 | §30 / S-57 / §2.35 | full-surface intake (classifier + probe groups + v1.1 profile) | `829a284` |
| CL-547 | §30.1 | design engines consume probe commitments (translate + recommend) | `c23e5fe` |
| CL-548 | §30.2 | precise cloud classification + azure/gcp/cfn probes + `unprobed_in_scope` | `43ea692` |
| CL-549 | §30.3 | word-boundary classifier matching (kata-precision fix) | **`f39fcdc`** |

Latest `main` HEAD is **`f39fcdc`** — pinning there adopts all four (+ the submission-isolation `.gitignore`
guard). To resume the kata, see the companion **`docs/handoff-ctp-to-gctp-resume-kata.md`**.

## 1. Coordinate correction (READ FIRST)

GCTP filed P-12 as **"§27.16 Full-Surface Intake"**. **§27.16 already exists** in CTP's architecture
("Layered multi-cloud advisor", 2026-06-08) — that label is a collision. CTP owns its decomposition, so
P-12 landed at CTP-correct coordinates:

| GCTP proposed | CTP landed |
|---|---|
| §27.16 | **§30** (new top-level; §27.16 taken) |
| (no feature ID) | **S-57** (next after S-56/P-11) |
| (boundary contract) | **§2.35** (next after §2.34/P-11) |
| MODIFY `business-intake.sh` | **NEW** `commands/full-surface-intake.sh` composing S-32 (more additive; v1.0 untouched) |
| `evals/business-intake-v1.14-eval.yaml` | per-spec `evals/specs/cl546-fsintake-01..12.json` (CTP spec convention) |

## 2. Coordinates

| | |
|---|---|
| Repo | `drumfiend21/claude-tdd-pro` (CTP) · Branch `main` |
| Re-pin target SHA | **`f39fcdc`** — `f39fcdc6a8a450a087389f22a95ed17f9cfec7d1` (adopts CL-546+547+548+549) |
| Changes | `CL-546` (S-57 / §2.35 / §30) · `CL-547` (§30.1) · `CL-548` (§30.2) |
| New command | `commands/full-surface-intake.sh` |
| New corpora | `standards/business-intake-workload-classifier.yaml`, `standards/business-intake-question-bank.yaml` |
| New schema | `schemas/business-profile.schema.json` |
| Consumers wired (§30.1) | `commands/business-translate.sh`, `commands/architect-recommend.sh` |
| Design | `docs/design/v1.14-full-surface-intake.md` · Architecture §30 / §30.1 / §30.2 |
| Specs | `evals/specs/cl546-fsintake-01..12`, `cl547-consume-01..08`, `cl548-cover-01..08.json` |

## 3. THE AUTHORITATIVE v1.1 CONTRACT (reconcile your PENDING validator to this)

CTP is authoritative on the shape; your `--validate-profile` / `handoff-contract.md §Business-Intake` should
be reconciled to these exact keys. A v1.1 `business-profile.json`:

```json
{
  "schema_version": "1.1",
  "generated_at": "<iso>",
  "complete": true,
  "answers": { "...universal 9, mirrored UNCHANGED..." },
  "workload_classification": {
    "workload_types": ["web-frontend", "rest-api", "aws-platform", "..."],
    "namespaces": ["react", "node", "k8s", "aws", "..."],
    "activated_probe_namespaces": ["react", "jwt", "k8s", "aws", "..."],
    "unprobed_in_scope": ["md", "mesh", "..."]
  },
  "probes": { "react": { "react_rendering_model": "spa" }, "jwt": { "jwt_token_lifetime": "short" } },
  "grounded_in": ["...universal source_ids ∪ answered-probe source_ids (STRICT SUPERSET)..."],
  "grounded_in_namespaces": ["react", "jwt", "k8s"],
  "unanswered": []
}
```

**§30.2 additive key — `workload_classification.unprobed_in_scope`:** in-scope namespaces with no probe
group, reported EXPLICITLY (never silent). It is an ADDITIVE optional key; your `--validate-profile` checks
required keys, so tolerate it as an allowed optional field (do not fail on its presence). Namespaces listed
here carry no distinct founder commitment and are grounded at output time by §29.

**§2.35 — 3 boundary surfaces:**
1. **Schema** `schemas/business-profile.schema.json` — `oneOf` on `schema_version`: v1.0 ∪ v1.1 both valid;
   v1.1 additionally requires `workload_classification` + `probes` + `grounded_in_namespaces`. Validatable
   by CTP's own `rubric/detectors/lib/validate-json-schema.js` (no npm dep).
2. **`--list-questions`** → `{ universal_source, probe_groups: { <ns>: [ …questions… ] } }`;
   **`--classify`** → `{ workload_classification: {...} }` on stdout.
3. **`source_id ↔ namespace` traceability** — every probe cites an existing catalog `source_id`; every
   `grounded_in_namespaces` entry is an `activated_probe_namespaces` entry backed by ≥1 answered probe.

**Additivity invariants (all tested):** universal 9 stay universal · v1.0 profiles still validate ·
`grounded_in` is a strict superset · no rule relaxed.

**Your invariant-4 (probe-group → decision propagation) holds:** every `activated_probe_namespaces` entry
is a real aggregator namespace, so a v1.1 probe answer maps to rules via `source_namespace`.

## 4. Command surface

```
full-surface-intake.sh --workload <text>
  [--classify | --list-questions]
  [--answer k=v]... [--answers <json>]          # universal (forwarded to S-32, validated there)
  [--probe-answer ns:key=value]...              # per-namespace probes (bare key=value also resolved)
  [--with-data] [--out <path>] [--now <iso>] [--partial] [--dry-run]
```
Exit: `0` complete/classify/list/partial/dry-run · `1` incomplete (probes unanswered) · `2` usage/invalid
(bad universal enum delegated to S-32; bad probe enum caught here).

## 5. §30.1 — design engines consume the commitments (CL-547)

Originally CL-546 left the consumers untouched (the profile carried `probes` but nothing steered option
choice). Your KATA audit flagged this open half; CL-547 closes it (extends S-33/S-34; no new feature ID):

- **`business-translate.sh` (S-33)** reads `probes.<namespace>` → adds a GROUNDED concern per committed
  posture, cited by the probe `source_id` (`owasp_threat_posture=adversarial`→threat_modeling+pentest;
  `slsa_build_level=l3`→provenance_attestation; `react_accessibility_target=wcag-aa`→accessibility_conformance;
  `aws_region_strategy=multi-region`→multi_region; `k8s_multitenancy=multi-tenant`→namespace_isolation; …).
  Emits `probes_consumed=<n>`. Grounding-verification now also loads `eo-security-sources.yaml` + `sources.yaml`
  (additive — can only reduce `needs_grounding`).
- **`architect-recommend.sh` (S-34)** lets a decisive commitment move the pick: `aws/azure/gcp_region_strategy
  =multi-region` upgrades a balanced default to the most-resilient option; `aws_cost_guardrails=hard-caps`
  pulls to cost-optimized. Emits `probes_consumed=<n>`.
- **Back-compat by construction:** both paths gate on `probes` presence; a v1.0 profile is byte-for-byte
  unchanged (`probes_consumed=0`, same pick).

## 5a. §30.2 — precise cloud classification + IaC coverage + transparency (CL-548)

Closes the coverage gap your KATA readiness audit flagged (`azure/gcp/cfn/ansible` were in-scope-but-unprobed):

- **Precise cloud classification** — `iac-cloud` now scopes only provider-agnostic namespaces (`hashicorp`,
  `iam`, `security-governance`); dedicated `aws-platform`/`azure-platform`/`gcp-platform`/`cloudformation`/
  `config-management` types fire on cloud-specific signals. **An AWS-only kata is probed for `aws`+`cfn`, not
  Azure/GCP.** (Also removed `aws/azure/gcp` from `relational-data`/`nosql-data` scope — a DB signal alone no
  longer drags clouds in; the cloud signals do.)
- **IaC probe coverage** — grounded probe groups added for `azure` (azure-well-architected /
  azure-architecture-center), `gcp` (gcp-architecture-framework / gcp-architecture-center), `cfn`
  (aws-cloudformation-best-practices). Consumed by `business-translate` (`azure/gcp_region_strategy=multi-region`
  →multi_region; `cfn_stack_policy=protected`→stack_protection). `ansible` stays unprobed (no grounded
  founder-decision source) and is REPORTED, not dropped.
- **Transparency marker** — `workload_classification.unprobed_in_scope` (+ stderr marker on `--classify` and
  the run). No in-scope namespace is silently unprobed. Remaining unprobed (CI-platform alternatives,
  `md`/`mesh`/`compose`/`web-vitals`) carry no distinct founder commitment; grounded at output by §29.

## 6. Verification (CTP side)

- Full suite **4,939 / 0** at `43ea692` (4911 → 4923 → 4931 → 4939 across CL-546/547/548).
- `cl546-fsintake-01..12` (intake) · `cl547-consume-01..08` (design consumption) · `cl548-cover-01..08`
  (precise classification + IaC coverage + transparency). Deterministic + tool-independent.
- Append-only: each CL `git diff --numstat docs/architecture-v1.9.md` = insertions / **0 deletions**.

## 7. GCTP next steps (TICKET-114..116)

1. §15-gated pin bump to **`43ea692`** (additive-only contract-drift check passes; only `architecture-v1.9.md`
   drifts — the §30/§30.1/§30.2 appends).
2. `docs/handoff-contract.md §Business-Intake` → authoritative shape in §3 (your anticipated
   `workload_classification` / `probes.<namespace>` / `grounded_in_namespaces` all match).
3. **Tolerate the additive `unprobed_in_scope` key** in `--validate-profile` (optional field; do not fail on it).
4. Run `docs/handoff-ctp-p12-acceptance-test.sh` against the `43ea692` cache; `--classify` output is under a
   top-level `workload_classification` key (now including `unprobed_in_scope`).
5. Live `/consult` on the Certifiable kata; `--validate-profile` → exit 0 with `schema_version=1.1`; verify
   crosscheck invariant 4 fires (keys on `activated_probe_namespaces`).
6. Flip `docs/upstream-ctp-proposals.md §P-12` 📋 FILED → ✅ ADOPTED at `43ea692`.

## 8. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. All three CLs additive (new command + 2 corpora + schema +
28 specs + §30/§30.1/§30.2 amendments; 0 deletions to existing architecture content). Mirror of P-10 / P-11.
