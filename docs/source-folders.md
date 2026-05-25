# Source folders

H-9 progressive disclosure: how `generated-code-quality-standards/` is
organized and which file you edit for what.

## Top-level layout

```
generated-code-quality-standards/
├── _universal/           Highest-priority cross-cutting ruleset
│   └── ai-dev-corpus.md
├── google-jsguide/       Google's JS style guide rules
├── google-tsguide/       Google's TS style guide rules
├── google-pyguide/       Google's Python style guide rules
├── google-eng-practices/ Google's eng practices (review, design)
├── google-testing-blog/  Testing-on-the-toilet patterns
├── react-docs/           Official React docs rules
├── react-rsc-rfc/        Server Components RFC rules
├── nextjs-docs/          Next.js docs rules
├── typescript-handbook/  TS handbook rules
├── node-docs/            Node official docs rules
├── node-best-practices/  Goldbergyoni node-best-practices
├── owasp-asvs/           OWASP ASVS controls
├── owasp-top10/          OWASP Top 10 rules
├── wcag-2-2/             WCAG 2.2 accessibility
├── web-vitals/           Core Web Vitals thresholds
├── slsa/                 SLSA supply-chain levels
└── semver/               SemVer rules
```

## Rule file shape (G-1)

Each `<source-folder>/<rule-id>.yaml` has:

```yaml
name: <descriptive>
rules:
  - id: <rule-id>
    name: <human-readable>
    description: <what the rule prevents>
    detector: rubric/detectors/<rule-id>.sh
    severity: error | warn | off
    options_schema: { ... }
    source:
      url: <upstream URL>
      fetched_at: <ISO8601>
      content_hash: <sha256>
```

## Edit which file?

- **Want to add a new rule for an existing source?**
  Add a YAML file to the appropriate `<source-folder>/`.
- **Want to add a whole new source (e.g., a new framework)?**
  Use `/standards-add <url>` (S-14) — it scaffolds the new folder.
- **Want to remove a source?**
  `/standards-remove <id>` (S-15) handles archival.

## Operator override surface

- **Whole-rule override:** profile `rules: { <id>: off | warn | error }`.
- **Per-glob override:** profile `overrides: [{ files, rules }]` plus
  the recipe files under `profiles/_overrides/`.
- **Inline suppression (E-5):**
  `// rubric-disable-line <rule-id> -- <justification>`.
