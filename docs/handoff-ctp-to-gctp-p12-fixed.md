# CTP → GCTP handoff — P-12 BUILT: full-surface requirements intake

**Written:** 2026-07-04 · **From:** CTP (`claude-tdd-pro`) maintainer session
**Re:** GCTP inbound proposal P-12 (full-surface intake) / TICKET-114
**Status:** ✅ ASSESSED · CONFIRMED · BUILT (additive) · TESTED · MERGED TO `main`
**Ask fulfilled:** new feature + contract + section via the append-only amendment — **but at CTP-correct coordinates** (see §1).

## 0. TL;DR

P-12 is correct: CTP's **output** was full-surface (§29/P-11) but its **intake** was a fixed universal-9
questionnaire, so most namespaces grounded from defaults, not stated facts. Fixed additively with **S-57
`commands/full-surface-intake.sh`** + contract **§2.35** + section **§30**: a workload classifier + per-
namespace probe groups produce a **v1.1 `business-profile.json`** that is a strict additive superset of
v1.0. **Re-pin CTP → `829a284` and execute TICKET-114.**

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
| Re-pin target SHA | **`829a284`** — `829a284ea181d67a520f87a136430f60dcf3a492` |
| Change | `CL-546` (S-57 / §2.35 / §30) |
| New command | `commands/full-surface-intake.sh` |
| New corpora | `standards/business-intake-workload-classifier.yaml`, `standards/business-intake-question-bank.yaml` |
| New schema | `schemas/business-profile.schema.json` |
| Design | `docs/design/v1.14-full-surface-intake.md` · Architecture §30 |
| Specs | `evals/specs/cl546-fsintake-01..12.json` |

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
    "workload_types": ["web-frontend", "rest-api", "..."],
    "namespaces": ["react", "node", "k8s", "..."],
    "activated_probe_namespaces": ["react", "jwt", "k8s", "..."]
  },
  "probes": { "react": { "react_rendering_model": "spa" }, "jwt": { "jwt_token_lifetime": "short" } },
  "grounded_in": ["...universal source_ids ∪ answered-probe source_ids (STRICT SUPERSET)..."],
  "grounded_in_namespaces": ["react", "jwt", "k8s"],
  "unanswered": []
}
```

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

## 5. What CTP did NOT change (so your integration is smaller)

- `business-translate.sh` / `architect-recommend.sh` / `architect-session.sh` — **untouched**; they read
  `answers` (unchanged), so the whole existing chain works on a v1.1 profile. Wiring them to *read* `probes`
  for richer grounding is a CTP follow-up CL, not part of this contract.
- `standards/eo-security-sources.yaml` / `cloud-architecture-sources.yaml` — **untouched**; every probe
  reuses an existing `source_id` (per your manifest correction, most sources already existed).

## 6. Verification (CTP side)

- Full suite **4,923 / 0** at `829a284` (4911 → 4923; cold run).
- `cl546-fsintake-01..12`: classifies-distributed · activates-only-in-scope · grounded_in-strict-superset ·
  universal-mirrored · probes-recorded · incomplete-until-answered · rejects-bad-probe · delegates-universal-
  validation · v1.1-schema-valid · v1.0-still-valid · grounds-only-from-answers · list-questions-probes.
- Append-only: `git diff --numstat docs/architecture-v1.9.md` = 12 insertions / 0 deletions.

## 7. GCTP next steps (TICKET-114)

1. §15-gated pin bump `0cf28fe → 829a284` (additive-only contract-drift check passes).
2. `docs/handoff-contract.md §Business-Intake` — flip PENDING → authoritative shape in §3 above; reconcile
   any key-name drift (your anticipated `workload_classification` / `probes.<namespace>` /
   `grounded_in_namespaces` all match).
3. Run `docs/handoff-ctp-p12-acceptance-test.sh` against the `829a284` cache — the `--classify` and v1.1
   sections should now go green (note `--classify` output is under a top-level `workload_classification` key).
4. Live `/consult` on the Certifiable kata; `--validate-profile` should return exit 0 with
   `schema_version=1.1`; verify crosscheck invariant 4 fires.
5. Flip `docs/upstream-ctp-proposals.md §P-12` 📋 FILED → ✅ ADOPTED at `829a284`.

## 8. Boundary (unchanged)

CTP did not edit GCTP; GCTP does not edit CTP. Additive: new command + 2 corpora + schema + 12 specs + §30
amendment (0 deletions to existing architecture content). Mirror of the P-10 / P-11 round-trips.
