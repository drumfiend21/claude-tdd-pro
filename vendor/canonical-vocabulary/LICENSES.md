# Canonical-vocabulary mirror licenses

The 4-axis canonical vocabulary (ADR-0008, §28.28) binds rules to tools via four
industry-standard authorities instead of CTP-invented strings. Every mirror in this
directory is derived from a **permissively licensed** upstream — **free to use,
distribute, modify, and use commercially**, with attribution. No copyleft (GPL/AGPL/LGPL)
and no non-commercial restriction is present in any mirrored source.

| Mirror | Axis | Upstream | License | Commercial use |
|---|---|---|---|---|
| `linguist-languages.json` | Languages (`applies_to.linguist_aliases`) | [github-linguist/linguist](https://github.com/github-linguist/linguist) `lib/linguist/languages.yml` | **MIT** | ✅ |
| `purl-types.json` | Package use (`applies_to.purl_uses`) | [package-url/purl-spec](https://github.com/package-url/purl-spec) | **MIT** | ✅ |
| `k8s-gvks.json` | K8s objects (`applies_to.k8s_gvks`) | [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes) built-in API | **Apache-2.0** | ✅ |
| `iac-dialects.json` | IaC dialects (`applies_to.iac_dialects`) | [Checkov](https://github.com/bridgecrewio/checkov) + [Trivy](https://github.com/aquasecurity/trivy) + [Kubescape](https://github.com/kubescape/kubescape) supported-framework union | **Apache-2.0** | ✅ |

## Attribution

- **GitHub Linguist** © GitHub, Inc. — MIT License.
- **PURL / package-url spec** © the purl-spec authors — MIT License.
- **Kubernetes** © The Kubernetes Authors — Apache License 2.0.
- **Checkov** © Prisma Cloud / Bridgecrew, **Trivy** © Aqua Security, **Kubescape** © ARMO — each Apache License 2.0.

## Refresh

`refresh-vocabulary.sh` re-materializes these mirrors (Linguist live-fetched; PURL/K8s/IaC
from the embedded curated source-of-truth). `provenance.json` records per-mirror authority,
URL, license, `fetched_at`, and `content_hash`. The Linguist axis tracks upstream through the
§28.22/§28.23 daily refresh; the curated axes are stable enumerations updated by code change.

## Policy

Per operator directive, CTP ships **only** open-source, free-to-use-and-distribute (incl.
commercial) material. Any future vocabulary axis or tool added to the engine MUST carry a
permissive license (MIT/Apache-2.0/BSD/ISC/MPL-2.0/CC-BY/CC0) recorded here; GPL/AGPL tools
may be *invoked* as external, arms-length subprocesses but are **never bundled or distributed**
in this repository, and no non-commercial-restricted source is mirrored.
