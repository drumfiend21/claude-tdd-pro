# Community contribution review process

Per architecture §16 H-10: this directory holds community-contributed PR
sources, compliance frameworks, and rules. Promotion to tier 1 requires
**two reviewer approvals**.

## Required fields on every entry

- `id` — globally unique identifier
- `contributor` — identity of the proposer (gh handle, email, or org)
- `review_status` — `pending` | `approved` | `rejected`
- `eval_evidence` — pointer to passing evals or attestation
- `license` — SPDX identifier
- `reviewers` — list of approving reviewers (≥2 required for tier 1)
- `proposed_tier` — target tier (1, 2, 3)

## Promotion contract

| Proposed tier | Reviewers required |
|---|---|
| 1 | 2 |
| 2 | 1 |
| 3 | 0 (anyone can use; not endorsed) |

Run `bash community/validate.sh --entry <file.yaml>` to check field
completeness, then `bash community/promote.sh --entry <file.yaml>` to
apply the promotion gate.
