// commands/promote-toolchain.js — single source of truth for the composite-engine FOSS toolchain.
// Emits rubric/runners/toolchain.json (install + SARIF exec spec per tool) AND
// standards/kind-to-tool-routing.yaml (kind -> tools, derived from each tool's `kinds`).
// Run: node commands/promote-toolchain.js
//
// exec.mode: "sarif" = tool prints SARIF 2.1.0 to stdout with exec.args;
//            "sarif-file" = tool writes SARIF to <outdir>/<exec.out>; "exit" = exit-code mode
//            (0 clean / non-0 findings -> generic SARIF synthesized from output lines).
// License policy: GPL/AGPL/LGPL tools are invoke_only (run arms-length, never bundled).
const fs = require("fs");

// [tool, bin, installer, package, license, invoke_only, sarif_native, exec_mode, exec_args, kinds[]]
const T = [
  // ---- universal / cross-language ----
  ["semgrep","semgrep","pipx","semgrep","LGPL-2.1",true,true,"sarif","--sarif --quiet --config auto",["typescript","javascript","python","go","java","ruby","php","rust","scala","kotlin"]],
  ["trivy","trivy","binary","aquasecurity/trivy","Apache-2.0",false,true,"sarif","fs --format sarif --quiet",["terraform","kubernetes","dockerfile","npm","pypi"]],
  ["osv-scanner","osv-scanner","binary","google/osv-scanner","Apache-2.0",false,false,"exit","--lockfile",["npm","pypi","maven","cargo","go"]],
  ["syft","syft","binary","anchore/syft","Apache-2.0",false,false,"exit","scan",["sbom"]],
  ["grype","grype","binary","anchore/grype","Apache-2.0",false,true,"sarif","-o sarif",["npm","pypi","maven","sbom"]],
  ["gitleaks","gitleaks","binary","gitleaks/gitleaks","MIT",false,true,"exit","detect --no-git --source",["secrets"]],
  ["detect-secrets","detect-secrets","pipx","detect-secrets","Apache-2.0",false,false,"exit","scan",["secrets"]],
  ["trufflehog","trufflehog","binary","trufflesecurity/trufflehog","AGPL-3.0",true,false,"exit","filesystem",["secrets"]],
  ["conftest","conftest","binary","open-policy-agent/conftest","Apache-2.0",false,true,"exit","test",["rego","kubernetes"]],
  ["regal","regal","binary","open-policy-agent/regal","Apache-2.0",false,false,"exit","lint",["rego"]],
  ["scorecard","scorecard","binary","ossf/scorecard","Apache-2.0",false,false,"exit","--local",["supply-chain"]],
  // ---- javascript / typescript ----
  ["eslint","eslint","npm","eslint","MIT",false,true,"exit","",["typescript","javascript"]],
  ["biome","biome","npm","@biomejs/biome","MIT",false,false,"exit","lint",["typescript","javascript"]],
  ["oxlint","oxlint","npm","oxlint","MIT",false,false,"exit","",["typescript","javascript"]],
  ["prettier","prettier","npm","prettier","MIT",false,false,"exit","--check",["typescript","javascript","css","html","json","yaml","markdown"]],
  ["graphql-schema-linter","graphql-schema-linter","npm","graphql-schema-linter","MIT",false,false,"exit","",["graphql"]],
  // ---- css / html / a11y ----
  ["stylelint","stylelint","npm","stylelint","MIT",false,true,"exit","",["css","scss","less"]],
  ["htmlhint","htmlhint","npm","htmlhint","MIT",false,true,"exit","",["html"]],
  ["html-validate","html-validate","npm","html-validate","MIT",false,true,"exit","",["html"]],
  ["pa11y","pa11y","npm","pa11y","MIT",false,false,"exit","",["html","accessibility"]],
  ["lighthouse","lighthouse","npm","lighthouse","Apache-2.0",false,false,"exit","--quiet",["html","accessibility","performance"]],
  // ---- IaC ----
  ["checkov","checkov","pipx","checkov","Apache-2.0",false,true,"sarif-file","-f",["terraform","kubernetes","cloudformation","helm","dockerfile","github_actions","ansible"]],
  ["tfsec","tfsec","binary","aquasecurity/tfsec","MIT",false,true,"sarif","--format sarif",["terraform"]],
  ["terrascan","terrascan","binary","tenable/terrascan","Apache-2.0",false,true,"exit","scan",["terraform","kubernetes"]],
  ["tflint","tflint","binary","terraform-linters/tflint","MPL-2.0",false,false,"exit","",["terraform"]],
  ["cfn-lint","cfn-lint","pipx","cfn-lint","MIT-0",false,true,"sarif","--format sarif",["cloudformation"]],
  // ---- kubernetes ----
  ["kubescape","kubescape","binary","kubescape/kubescape","Apache-2.0",false,true,"sarif","scan --format sarif --format-version v2",["kubernetes"]],
  ["kube-linter","kube-linter","binary","stackrox/kube-linter","Apache-2.0",false,true,"sarif","lint --format sarif",["kubernetes"]],
  ["kubeconform","kubeconform","binary","yannh/kubeconform","Apache-2.0",false,false,"exit","",["kubernetes"]],
  ["polaris","polaris","binary","FairwindsOps/polaris","Apache-2.0",false,true,"exit","audit --audit-path",["kubernetes"]],
  // ---- openapi / github actions / containers ----
  ["spectral","spectral","npm","@stoplight/spectral-cli","Apache-2.0",false,true,"exit","lint",["openapi"]],
  ["vacuum","vacuum","npm","@quobix/vacuum","Apache-2.0",false,false,"exit","lint",["openapi"]],
  ["redocly","redocly","npm","@redocly/cli","MIT",false,false,"exit","lint",["openapi"]],
  ["zizmor","zizmor","binary","zizmorcore/zizmor","Apache-2.0",false,true,"sarif","--format sarif",["github_actions"]],
  ["actionlint","actionlint","binary","rhysd/actionlint","MIT",false,false,"exit","",["github_actions"]],
  ["hadolint","hadolint","binary","hadolint/hadolint","GPL-3.0",true,true,"sarif","--format sarif",["dockerfile"]],
  // ---- yaml / json ----
  ["yamllint","yamllint","pipx","yamllint","GPL-3.0",true,false,"exit","-f parsable",["yaml"]],
  ["ajv","ajv","npm","ajv-cli","MIT",false,false,"exit","validate -s",["jsonschema"]],
  // ---- rust / go / python ----
  ["clippy","cargo-clippy","cargo","clippy","MIT",false,false,"exit","clippy",["rust"]],
  ["cargo-audit","cargo-audit","cargo","cargo-audit","MIT",false,false,"exit","audit",["rust"]],
  ["cargo-deny","cargo-deny","cargo","cargo-deny","MIT",false,false,"exit","check",["rust"]],
  ["golangci-lint","golangci-lint","binary","golangci/golangci-lint","MIT",false,true,"sarif","run --out-format sarif",["go"]],
  ["govulncheck","govulncheck","go","golang.org/x/vuln/cmd/govulncheck","BSD-3-Clause",false,false,"exit","",["go"]],
  ["gosec","gosec","go","github.com/securego/gosec/v2/cmd/gosec","Apache-2.0",false,true,"sarif","-fmt sarif",["go"]],
  ["staticcheck","staticcheck","go","honnef.co/go/tools/cmd/staticcheck","MIT",false,false,"exit","",["go"]],
  ["ruff","ruff","pipx","ruff","MIT",false,true,"sarif","check --output-format sarif",["python"]],
  ["bandit","bandit","pipx","bandit","Apache-2.0",false,true,"sarif","-f sarif",["python"]],
  ["mypy","mypy","pipx","mypy","MIT",false,false,"exit","",["python"]],
  ["pip-audit","pip-audit","pipx","pip-audit","Apache-2.0",false,true,"exit","",["python","pypi"]],
  // ---- jvm / kotlin / swift / dotnet / ruby / others ----
  ["spotbugs","spotbugs","binary","spotbugs/spotbugs","LGPL-2.1",true,true,"sarif","",["java"]],
  ["pmd","pmd","binary","pmd/pmd","BSD-2-Clause",false,true,"exit","check",["java"]],
  ["ktlint","ktlint","binary","pinterest/ktlint","MIT",false,true,"exit","",["kotlin"]],
  ["detekt","detekt","binary","detekt/detekt","Apache-2.0",false,true,"exit","",["kotlin"]],
  ["swiftlint","swiftlint","binary","realm/SwiftLint","MIT",false,true,"exit","",["swift"]],
  ["rubocop","rubocop","gem","rubocop","MIT",false,true,"exit","",["ruby"]],
  ["brakeman","brakeman","gem","brakeman","MIT",false,true,"exit","",["ruby"]],
  ["credo","credo","manual","credo","MIT",false,false,"exit","",["elixir"]],
  ["phpstan","phpstan","manual","phpstan/phpstan","MIT",false,true,"exit","analyse",["php"]],
  ["psalm","psalm","manual","vimeo/psalm","MIT",false,true,"exit","",["php"]],
  ["slither","slither","pipx","slither-analyzer","AGPL-3.0",true,true,"exit","",["solidity"]],
  ["solhint","solhint","npm","solhint","MIT",false,true,"exit","",["solidity"]],
  ["shellcheck","shellcheck","binary","koalaman/shellcheck","GPL-3.0",true,true,"exit","",["shell"]],
  ["shfmt","shfmt","binary","mvdan/sh","BSD-3-Clause",false,false,"exit","-d",["shell"]],
  ["sqlfluff","sqlfluff","pipx","sqlfluff","MIT",false,false,"exit","lint",["sql"]],
  ["buf","buf","binary","bufbuild/buf","Apache-2.0",false,false,"exit","lint",["protobuf"]],
  ["protolint","protolint","binary","yoheimuta/protolint","MIT",false,false,"exit","lint",["protobuf"]],
  // ---- architectural-content bundle (prose / markdown / ADR) ----
  ["markdownlint","markdownlint-cli2","npm","markdownlint-cli2","MIT",false,true,"exit","",["markdown","architectural-content"]],
  ["remark","remark","npm","remark-cli","MIT",false,false,"exit","--quiet --frail",["markdown","architectural-content"]],
  ["vale","vale","binary","errata-ai/vale","MIT",false,true,"exit","",["markdown","architectural-content"]],
  ["textlint","textlint","npm","textlint","MIT",false,true,"exit","",["markdown","architectural-content"]],
  ["alex","alex","npm","alex","MIT",false,false,"exit","",["markdown","architectural-content"]],
  ["write-good","write-good","npm","write-good","MIT",false,false,"exit","",["markdown","architectural-content"]],
  ["cspell","cspell","npm","cspell","MIT",false,true,"exit","--no-progress --no-summary",["markdown","architectural-content"]],
  ["codespell","codespell","pipx","codespell","GPL-2.0",true,false,"exit","",["markdown","architectural-content"]],
  ["lychee","lychee","binary","lycheeverse/lychee","Apache-2.0 OR MIT",false,true,"exit","--no-progress",["markdown","architectural-content"]],
  ["markdown-link-check","markdown-link-check","npm","markdown-link-check","MIT",false,false,"exit","",["markdown","architectural-content"]],
  ["reuse","reuse","pipx","reuse","GPL-3.0",true,true,"exit","lint",["architectural-content"]],
  ["mmdc","mmdc","npm","@mermaid-js/mermaid-cli","MIT",false,false,"exit","-i",["architectural-content"]],
  ["commitlint","commitlint","npm","@commitlint/cli","MIT",false,false,"exit","--edit",["architectural-content"]],
  ["adr-tools","adr","binary","npryce/adr-tools","MIT",false,false,"exit","list",["architectural-content"]]
];

// Pure FORMATTERS: a non-zero exit means "would reformat" (auto-fixable style), NOT a correctness
// violation. They are ADVISORY — they verify the file is well-formed/parseable, but their style
// opinions never produce a blocking red. (Linters/validators/scanners stay blocking.)
const ADVISORY = new Set(["prettier","shfmt"]);

const tools = T.map(([tool,bin,installer,pkg,license,invoke_only,sarif_native,mode,args,kinds]) => {
  const e = { tool, installer, package: pkg, bin, license, kinds, sarif_native, exec: { mode, args } };
  if (invoke_only) e.invoke_only = true;
  if (ADVISORY.has(tool)) e.advisory = true;
  if (mode === "sarif-file") e.exec.out = "results_sarif.sarif";
  // binary tools install from their upstream release page (owner/repo -> GitHub releases).
  if (installer === "binary") e.install_url = /\//.test(pkg) ? `https://github.com/${pkg}/releases` : `https://github.com/${pkg}`;
  return e;
});

const manifest = {
  _doc: "Composite-engine FOSS toolchain manifest (install + SARIF exec spec). Source of truth: commands/promote-toolchain.js. Read by install-toolchain.sh (install), run-tool.sh (exec), audit-commercial-license.sh (license).",
  _license_policy: "Every tool open-source + free for commercial use. Permissive installs by default; GPL/AGPL/LGPL are invoke_only (arms-length subprocess, never bundled/redistributed).",
  _count: tools.length,
  tools
};
fs.writeFileSync("rubric/runners/toolchain.json", JSON.stringify(manifest, null, 2) + "\n");

// ---- derive kind-to-tool-routing.yaml from each tool's kinds ----
const LING = new Set(["typescript","javascript","python","go","rust","ruby","php","java","kotlin","swift","scala","elixir","solidity","shell","sql","graphql","protobuf","css","scss","less","html","markdown","hcl","yaml","json","groovy"]);
const IAC = new Set(["terraform","kubernetes","cloudformation","helm","dockerfile","github_actions","gitlab_ci","ansible","openapi"]);
const PURL = new Set(["npm","pypi","maven","cargo","go-mod"]);
const byKind = {}; const bundle = [];
for (const [tool,bin,installer,pkg,license,invoke_only,sarif,mode,args,kinds] of T) {
  for (const k of kinds) {
    if (k === "architectural-content") { bundle.push({ tool, license, invoke_only }); continue; }
    (byKind[k] ||= []).push({ tool, license, invoke_only });
  }
}
const sect = (keys) => { const o={}; for (const k of Object.keys(byKind).sort()) if (keys.has(k)) o[k]=byKind[k]; return o; };
const dump = (obj, ind) => Object.entries(obj).map(([k,v]) => `  ${k}:\n` + v.map(t=>`    - { tool: ${t.tool}, license: ${JSON.stringify(t.license)}${t.invoke_only?", invoke_only: true":""} }`).join("\n")).join("\n");
let y = `# standards/kind-to-tool-routing.yaml — GENERATED by commands/promote-toolchain.js. Do not hand-edit.\n`;
y += `# Maps each 4-axis canonical kind to its FOSS enforcement tool(s); first listed = primary.\n`;
y += `# All tools open-source; GPL/AGPL/LGPL are invoke_only. Licenses governed by rubric/runners/toolchain.json.\n\n`;
y += `linguist_aliases:\n${dump(sect(LING))}\n\n`;
y += `iac_dialects:\n${dump(sect(IAC))}\n\n`;
y += `purl_uses:\n${dump(sect(PURL))}\n\n`;
// cross-cutting kinds (secrets/sbom/supply-chain/accessibility/...) preserved under their own key
const other = Object.keys(byKind).filter(k=>!LING.has(k)&&!IAC.has(k)&&!PURL.has(k)).sort();
if (other.length) { const o={}; for (const k of other) o[k]=byKind[k]; y += `cross_cutting:\n${dump(o)}\n\n`; }
y += `prose:\n  - { bundle: architectural-content }\n\n`;
y += `bundles:\n  architectural-content:\n`;
const seen=new Set();
for (const m of bundle) { if (seen.has(m.tool)) continue; seen.add(m.tool); y += `    - { tool: ${m.tool}, license: ${JSON.stringify(m.license)}${m.invoke_only?", invoke_only: true":""} }\n`; }
y += `    - { tool: prose-judge.sh, license: in-repo }\n`;
fs.writeFileSync("standards/kind-to-tool-routing.yaml", y);

console.error(`promote-toolchain: ${tools.length} tools -> toolchain.json; routing kinds=${Object.keys(byKind).length} bundle=${seen.size}`);
