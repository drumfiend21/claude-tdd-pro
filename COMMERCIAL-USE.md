# Commercial use & licensing policy

**You may use, modify, distribute, and SELL CTP (claude-tdd-pro) and GCTP commercially with no
licensing conflict.** This document states the policy and how it is machine-enforced.

The guarantee rests on one bright line, enforced by
[`rubric/detectors/audit-commercial-license.sh`](rubric/detectors/audit-commercial-license.sh)
(run in `/doctor` + CI):

## 1. Bundled / redistributed content → permissive only

Anything shipped **inside** the plugin (the data CTP redistributes) carries a **permissive or
attribution-only** license — safe to bundle in a commercial product:

| Bundled data | License | Commercial sale |
|---|---|---|
| `vendor/canonical-vocabulary/linguist-languages.json` | MIT | ✅ |
| `vendor/canonical-vocabulary/purl-types.json` | MIT | ✅ |
| `vendor/canonical-vocabulary/k8s-gvks.json` | Apache-2.0 | ✅ |
| `vendor/canonical-vocabulary/iac-dialects.json` | Apache-2.0 | ✅ |

Allowed for bundling: MIT, MIT-0, Apache-2.0, BSD-2/3-Clause, ISC, MPL-2.0, CC0, CC-BY (with
attribution), Unlicense, 0BSD, public domain. **Never bundled:** GPL/AGPL/LGPL *source*, CC-BY-**SA**
(share-alike), CC-**NC** (non-commercial), or proprietary content. The gate rejects any such license
on bundled data.

## 2. Invoke-only tools → installed separately, never shipped

The composite engine *invokes* FOSS tools as arms-length subprocesses; it does **not** bundle or
redistribute them. The user's package manager (npm/pipx/binary release) fetches each from its
upstream at install time. The default toolchain is **entirely permissive** (MIT/Apache-2.0); the
only copyleft tools are:

| Tool | License | Why it's safe to sell alongside |
|---|---|---|
| `semgrep` | LGPL-2.1 | invoke-only — run as a subprocess, never linked/bundled |
| `hadolint` | GPL-3.0 | invoke-only — run as a subprocess, never bundled |

Invoking a GPL/LGPL program as a separate process does **not** make the caller a derivative work,
and commercial **use** of GPL/LGPL software is unrestricted (copyleft governs distribution of
modified *source*, which CTP never does). Both are flagged `invoke_only: true` in
[`rubric/runners/toolchain.json`](rubric/runners/toolchain.json); the gate fails if any copyleft
tool is not so flagged. Operators who want a **zero-copyleft footprint** can install with
`--permissive-only` (or `CTP_TOOLCHAIN_PERMISSIVE_ONLY=1`), which skips them entirely.

## 3. Cited sources → provenance, not redistribution

CTP's rules are **CTP-authored original prose** that *cites* an authority for provenance (the
`provenance.source` + URL on each rule, and the source tables in
[`docs/standards-source-manifest.md`](docs/standards-source-manifest.md)). CTP does **not**
reproduce or redistribute the copyrighted text of those sources. Citation is not redistribution, so
a cited source may carry any license (incl. CC-BY-SA, GPL docs, or proprietary docs like AWS/MS/CIS)
without affecting CTP's own license or your right to sell it. The §2.33 citation auditor guarantees
every coding rule carries provenance; this gate governs only what is *bundled*.

## 4. GCTP inherits this by construction

GCTP consumes CTP as a pinned plugin. The contract surface that moves (`active.json` +
`rubric/detectors/`) is all permissive CTP-authored content. The FOSS toolchain GCTP relies on is
provisioned at install time the same way (CTP's installer), so GCTP is commercially sellable on the
same basis. **CTP does not edit GCTP and GCTP does not edit CTP.**

## Enforcement

`audit-commercial-license.sh` runs in CI and `/doctor` and **fails the build** on any bundled
non-permissive license or any unflagged copyleft tool — so this guarantee cannot silently regress.
The narrower guards (`cl489` vocabulary licenses, `cl490` routing-table licenses, `cl492` toolchain
licenses) remain as defense-in-depth.
