# Consumer Compatibility Contract (§28.40)

**Why this exists.** A CTP change can be *schema-additive* (new rule field, new rule class, new
detector) yet *breaking on a consumer's enforcement-STATE layer*. The two are different. A consumer
gate (e.g. GCTP's prose-projection floor) derives requirements from `active.json`'s **shape** and
compares them against **historical, pin-keyed state** (completed-ticket records, baselines, smoke
fixtures). When CTP adds a rule with `applies_to_prose: true`, that is additive on the rule body but
instantly demands every existing `.md`-scoped ticket carry the new rule — reds on legacy state that
was an honest green before the bump.

This contract makes that asymmetry **visible at design time** and gives consumers the metadata to
gate on, so a pin bump is consumer-safe on the enforcement-state layer, not only the CLI-signature
layer.

## The two paired invariants

### CTP-side invariant — "schema-additive with epoch + default"
Every new feature may add to the schema **provided**:

1. **Every rule carries an `introduced_in` epoch tag** (the CTP pin/version at which it first
   appeared; `baseline` = pre-contract, grandfathered). *Enforced by `audit-consumer-compatibility.sh`.*
2. **Every new optional, enforcement-relevant field declares its `absent_default`** in
   [`schemas/field-semantics.json`](../schemas/field-semantics.json), so a consumer reading old data
   (field missing) gets a defined answer instead of a new requirement. *Enforced by the gate.*
3. **No existing detector tightens behavior on inputs that previously passed** — or, if it must, the
   change ships with a `since: <version>` marker + a deprecation window, recorded in the
   `consumer_compatibility.detector_behavior_changes` block of the introducing ADR.
4. **Top-level plugin-tree additions are explicit in the handoff** (no surprise files) — listed in
   `consumer_compatibility.plugin_tree_additions`.

### GCTP-side invariant — "epoch-aware enforcement" (consumer's responsibility)
Every harness audit gate that derives requirements from `active.json` MUST gate by epoch:

1. **A floor requirement applies only to tickets/content issued at or after the floor's introducing
   pin** — read the rule's `introduced_in` and the ticket's issue-epoch; enforce only when
   `ticket-epoch ≥ rule-epoch`.
2. **Baselines are pin-keyed** (`cross-references-baseline.txt`, `hook-security-baseline.txt`, …); the
   pin-bump CL re-baselines them as part of its scope, with the diff visible in the ADR.
3. **Smoke fixtures opt into new contracts explicitly** (e.g. an `applies_to_floor_version` marker).
4. **Pre-commit gates that consume legacy state distinguish "rule violation" from
   "rule-not-yet-applicable-to-this-issuance-epoch."**

If both sides honor these, a pin-bump CL is: open handoff → bump pin → re-materialize cache +
regenerate `active.json` → re-baseline the pin-keyed files (visible in the ADR diff) → commit.
Green on first run. No deferred reds, no marker-gated transitions, no mass-rewrite temptation.

## Required block: every rule-schema-touching ADR fills this out

```yaml
consumer_compatibility:
  new_rule_classes:
    - <field_or_class>:
        introduced_in: <pin-or-version>
        absent_default: <value a consumer assumes when the field is missing>
        enforcement_impact: >
          Which consumer floor derives a requirement from this, and how much legacy state it reds
          without grandfathering (N rules × T existing matching tickets).
        grandfathering_required: yes|no
        grandfather_mechanism_proposed: <e.g. consumer gates by introduced_in epoch>
  detector_behavior_changes:
    - <detector.sh>:
        change: <what newly fires>
        smoke_fixture_impact: <does any clean toy file newly fail a universal rule?>
        deprecation_window: none|1 pin|2 pins
  plugin_tree_additions:
    - path: <top-level path added>
      consume_in_harness: yes|no|indirectly
      declare_in_registry: yes
  smoke_fixture_stable: <assertion that no clean toy file newly fails any universal rule at this pin>
```

## Retro-fill — the composite-engine line (pins 39903da → 230e99d)

```yaml
consumer_compatibility:
  new_rule_classes:
    - applies_to_prose:                       # introduced at the ADR-0007 line (§28.24/§28.26)
        introduced_in: baseline               # present before this contract; grandfather pre-adoption tickets
        absent_default: false
        enforcement_impact: >
          GCTP's prose-projection floor demands every .md-scoped ticket carry every rule with this
          flag. 9 curated rules carry it (aws/gcp/azure ingress, iam x2, jwt, k8s x2, gha). Existing
          .md-scoped tickets red until /decompose is re-run OR the floor gates by epoch.
        grandfathering_required: yes
        grandfather_mechanism_proposed: floor enforces only when ticket-epoch >= rule.introduced_in
    - enforced_by:                            # ADR-0008 §28.33
        introduced_in: baseline
        absent_default: "[{ tool: <detector>, required: true }]"
        enforcement_impact: >
          A `required` tool absent HARD-FAILS (red); an optional/absent tool is not_enforced
          (advisory). A consumer gate that treats not_enforced as red must read the `required` flag.
        grandfathering_required: no
    - applies_to:                             # ADR-0008 §28.29/§28.33
        introduced_in: baseline
        absent_default: "applies-to-all (no 4-axis restriction)"
        enforcement_impact: "Routing metadata; no new floor by itself."
        grandfathering_required: no
  detector_behavior_changes:
    - rubric/detectors/llm-judge.sh:
        change: "added --text (P-8 fix); prose-judge tier-2 now returns real verdicts under LLM_JUDGE=1 (was spurious not_enforced)"
        smoke_fixture_impact: "none with no model present (still degrades to not_enforced)"
        deprecation_window: none
    - hooks/scripts/enforce-standards-on-save.sh:
        change: "write-time now also runs the routed FOSS tools (composite-dispatch) + the bundle"
        smoke_fixture_impact: "a clean toy file is green/not_enforced, never newly red on a universal rule"
        deprecation_window: none
  plugin_tree_additions:
    - { path: vendor/,                 consume_in_harness: indirectly, declare_in_registry: yes }
    - { path: COMMERCIAL-USE.md,       consume_in_harness: no,         declare_in_registry: yes }
    - { path: schemas/field-semantics.json, consume_in_harness: yes,   declare_in_registry: yes }
  smoke_fixture_stable: >
    No clean toy file newly fails any universal rule at pin 230e99d: enforce-file/composite-dispatch
    return green or not_enforced (never red) on conformant content; new detectors only fire on real
    violations.
```

## Enforcement

`audit-consumer-compatibility.sh` (CI + `/doctor`) fails the build when any rule lacks
`introduced_in`, when an enforcement-relevant optional field is missing an `absent_default` in
`field-semantics.json`, or when this contract doc is absent — so the asymmetry cannot silently
re-enter. The GCTP-side invariant is the consumer's to implement (epoch-aware floors + pin-keyed
baselines); this contract gives it the `introduced_in` epoch + the `absent_default` registry it
needs to do so, and the handoff carries the filled `consumer_compatibility` block per pin bump.
