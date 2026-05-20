# ADR Index

Per architecture §16 W-4: every architectural decision is captured as an
ADR (Architecture Decision Record) under `docs/adr/`. Commits touching
ADR-tracked areas include a `Decision: <adr-id>` trailer. The full
trail surfaces in `/audit-pack` as the **Decision Trail** section,
which satisfies EU AI Act Art.12 record-keeping.

## Regeneration

Run `bash docs/adr/regenerate-index.sh --adr-dir docs/adr --index docs/adr/INDEX.md`
to pick up new ADR files. The W-1 architect skill auto-emits ADRs into
this directory; this index is rebuilt on every CL commit.

## Records

<!-- Auto-generated; do not hand-edit below this marker. -->
