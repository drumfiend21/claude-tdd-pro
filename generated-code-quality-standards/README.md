# Generated Code Quality Standards

Single source-organized directory holding every code-quality rule the plugin enforces, grouped by upstream publisher. Each `<namespace>/<file>.yaml` is a self-contained, ESLint-style rule configuration block sourced from one upstream publication.

## Primary ruleset (highest priority)

**[_universal/ai-dev-corpus.md](_universal/ai-dev-corpus.md)** is the primary, highest-priority ruleset on this project. It defines *how* software is architected, planned, and developed (mindset and methodology — English-first programming, Musk's 5-step algorithm, Anthropic's verification / context discipline, Building Effective Agents patterns). Code-quality rules in the namespaces below define *what* the final code must look like; the corpus governs the process that produces them. When the corpus conflicts with any per-language rule in this directory, the corpus wins on process and the language rule wins on output shape.

## Directory layout

```
generated-code-quality-standards/
├── google/                        # Google LLC published standards
├── us-government/                 # US Federal Government standards
├── european-union/                # EU regulations and guidance
├── finance-industry/              # Financial-industry standards + observed PRs
├── owasp/                         # OWASP Foundation
├── w3c/                           # W3C accessibility standards
├── web-vitals/                    # Core Web Vitals thresholds
├── react/                         # React official documentation patterns
├── node/                          # Node.js patterns
├── typescript/                    # TypeScript handbook patterns
├── slsa/                          # SLSA supply-chain framework
├── linux-foundation/              # Linux Foundation projects
├── industry-self-regulatory/      # Semver, Conventional Commits, etc.
├── _universal/                    # Cross-cutting rules (CL discipline, secret detection, refused flags)
├── _operator/                     # Your own custom rules (operator namespace)
├── _community/                    # Community-installed plugins
└── _meta/                         # Auto-generated index + attribution + namespacing docs
```

## File format

Every file follows the source-file schema (`schemas/source-file.schema.json`):

```yaml
source:
  id: <matches an entry in STANDARDS-URLS.yaml | COMPLIANCE-URLS.yaml | PR-SOURCES.yaml>
  authoritative_publisher: "<publishing body>"
  authoritative_url: <live URL>
  registry_link: <STANDARDS-URLS.yaml | COMPLIANCE-URLS.yaml | PR-SOURCES.yaml>
  fetched_at: <ISO 8601 timestamp>
  content_hash: sha256:...
  fetch_frequency: daily | weekly | monthly | quarterly
  fragility_tier: high | medium | low
  license_note: "..."

rules:
  - id: g-...
    name: ...
    # Full rubric rule per schemas/rubric-rule.schema.json
    ...

recommended_set:
  - g-...

all_set:
  - g-...
```

`recommended_set` MUST be a subset of `all_set`. `all_set` MUST equal exactly the set of rule IDs declared in `rules:`.

## Discoverability

- `_meta/INDEX.md` — auto-generated index of all files + rule counts
- `cat _meta/source-attribution.yaml` — mapping of folder → registry entry → upstream URL
- `_meta/rule-id-namespacing.md` — rule ID conventions and namespacing rules

## Operator-vs-plugin ownership

| Directory | Owned by | Updated via |
|---|---|---|
| `<namespace>/` (14 plugin folders) | Plugin | Plugin upgrade replaces files cleanly |
| `_operator/<my-org>/` | You | `/operator-namespace-init` or hand-edit; never touched by plugin upgrade |
| `_operator/<source-namespace>/<file>-extensions.yaml` | You | Extends/overrides plugin defaults via cascade (G-5/G-7) |
| `_community/<plugin-id>/` | Community | `/plugin-install <github-org>/<repo>`; `/plugin-update`; `/plugin-remove` |
| `_meta/` | Plugin (auto-generated) | Regenerated on every source-folder change |

## Profile activation

In your profile YAML, you can activate rules at granular per-source level:

```yaml
extends:
  - rubric:recommended            # cross-cutting recommended subset
  - google:tsguide                # recommended set from google/tsguide.yaml
  - google:*                      # recommended set from every file in google/
  - us-government:*:all           # all rules from every file in us-government/
  - owasp:asvs

exclude_sources:
  - linux-foundation:kubernetes-review-process    # too volume-heavy for my repo
  - finance-industry:bloomberg-memray-patterns    # not relevant
```

See [docs/source-folders.md](../docs/source-folders.md) for a deeper explanation.
