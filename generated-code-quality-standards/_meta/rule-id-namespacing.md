# Rule ID namespacing conventions

Rule IDs are stable global identifiers used across:
- Profile severity overrides (`rules: { <id>: error }`)
- Glob overrides (`overrides: [{ files: [...], rules: { <id>: off } }]`)
- Inline suppression (`// rubric-disable-next-line <id> -- justification`)
- ADR provenance (`Decision: <adr-id>` trailers)
- Audit log entries
- `/doctor --explain <id>` resolution chain

## Prefix convention

| Prefix | Origin | Example | Source-folder location |
|---|---|---|---|
| `g-` | Plugin-shipped (Generated quality standard) | `g-ts-001`, `g-react-007`, `g-node-001` | `<namespace>/<file>.yaml` |
| `g-universal-` | Cross-cutting plugin rule | `g-universal-cl-size`, `g-universal-secret-scan` | `_universal/<file>.yaml` |
| `<operator-id>-` | Operator-added | `acme-corp-001`, `my-team-002` | `_operator/<my-org>/<file>.yaml` |
| `<plugin-id>/` | Community plugin | `react-perf/no-array-index-key` | `_community/<plugin-id>/<plugin-namespace>/<file>.yaml` |

## Pattern (regex)

Rule IDs MUST match: `^[a-z][a-z0-9-]*(/[a-z][a-z0-9-]*)?$`

Enforced by `schemas/rubric-rule.schema.json` (CL-01).

## Stability guarantee

Rule IDs are stable across file moves. A rule moving from one source-folder file to another MUST preserve its ID. Profiles, suppressions, ADRs, and audit records remain valid through file reorganization.

## Deprecation pathway (E-10)

To rename or replace a rule ID:

1. Mark old rule `deprecated: true, replaced_by: [<new-id>]`
2. Add the new rule with the desired ID
3. Operators run `/migrate-rule <old-id> --to <new-id>` which updates profiles, ADRs, and inline suppressions
4. Old rule deprecated for ≥1 minor plugin version before removal
5. Removal recorded in `rubric/changelog.md` per O-10 rubric semver

## Cross-source citations

A rule may have multiple `provenance` entries citing different sources (e.g., `g-node-010` cites both `slsa` and `owasp-asvs`). The rule lives in its primary source file (the highest-tier or most-cited source); secondary citations are in the rule's `provenance` array.

## Conflict handling

Two files declaring the same rule `id`:
- Operator-namespace (`_operator/`) wins over plugin namespace
- Operator extension wins over plugin default for the same ID (cascade rule in G-5)
- Community plugin redefining a built-in rule ID is REJECTED at `/plugin-install` with clear error
