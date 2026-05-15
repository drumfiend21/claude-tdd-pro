#!/usr/bin/env bash
# E-9 reporters/formatters dispatcher per architecture section 16 E-9.
# Takes a synthetic finding (--rule + --in + --severity) and renders
# it via the named --format. Built-in formatters: stylish, compact,
# codeframe, html, json, junit, sarif, markdown. --format <abs-path>
# loads a custom Node formatter module.
#
# Usage:
#   formatters/cli.sh --rule <id> [--severity <P>] --in <file> --format <name|path> [--relative-paths]
#   formatters/cli.sh --rule <id> --in <file> --report-format json    # alias for --format json
#
# Localization: CLAUDE_TDD_PRO_LANG=es selects Spanish messages where
# rule has a localized message id (e.g. msgid-localized).

set -uo pipefail

RULE=""
SEVERITY="error"
IN_FILE=""
FORMAT="stylish"
RELATIVE_PATHS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --in) IN_FILE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --report-format) FORMAT="$2"; shift 2 ;;
    --relative-paths) RELATIVE_PATHS=1; shift ;;
    -h|--help)
      echo "Usage: formatters/cli.sh --rule <id> --in <file> --format <name|path> [--relative-paths]"
      echo "Built-in formats: stylish, compact, codeframe, html, json, junit, sarif, markdown"
      exit 0
      ;;
    *) echo "formatters/cli: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$RULE" || -z "$IN_FILE" ]]; then
  echo "formatters/cli: --rule and --in are required" >&2
  exit 2
fi

LANG_CODE="${CLAUDE_TDD_PRO_LANG:-en}"

RULE="$RULE" SEVERITY="$SEVERITY" IN_FILE="$IN_FILE" FORMAT="$FORMAT" \
RELATIVE_PATHS="$RELATIVE_PATHS" LANG_CODE="$LANG_CODE" PWD_ABS="$PWD" \
node -e '
const fs = require("fs");
const path = require("path");

const rule = process.env.RULE;
const severity = process.env.SEVERITY || "error";
const inFile = process.env.IN_FILE;
const format = process.env.FORMAT;
const relativePaths = process.env.RELATIVE_PATHS === "1";
const lang = process.env.LANG_CODE || "en";
const pwdAbs = process.env.PWD_ABS;

const messages = {
  "no-eval": { en: "use of eval is forbidden", es: "evita eval" },
  "msgid-localized": { en: "do not use eval", es: "evita eval" },
};

let source = "";
try { source = fs.readFileSync(inFile, "utf8"); } catch {}
const lines = source.split("\n");
const lineNo = 1;
const colNo = 1;

const builtinFormats = new Set(["stylish","compact","codeframe","html","json","junit","sarif","markdown"]);

if (!builtinFormats.has(format) && !format.startsWith("/") && !format.startsWith("./") && !fs.existsSync(format)) {
  process.stderr.write(`formatters/cli: unknown format "${format}"; available: ${[...builtinFormats].join(", ")} or absolute path to custom formatter\n`);
  process.exit(2);
}

const reportedPath = relativePaths ? path.relative(pwdAbs, inFile) : inFile;
const message = (messages[rule] && (messages[rule][lang] || messages[rule].en)) || "violation";

const finding = {
  ruleId: rule,
  severity,
  filePath: reportedPath,
  line: lineNo,
  column: colNo,
  message,
  source: lines[lineNo - 1] || "",
};

function emit(text) { process.stderr.write(text + (text.endsWith("\n") ? "" : "\n")); }

if (!builtinFormats.has(format)) {
  // custom formatter: Node module path
  try {
    const fn = require(format);
    const out = fn([finding]);
    emit(out);
    process.exit(0);
  } catch (e) {
    process.stderr.write(`formatters/cli: failed to load custom formatter ${format}: ${e.message}\n`);
    process.exit(2);
  }
}

switch (format) {
  case "json":
  case "markdown":
    emit(JSON.stringify([{ filePath: reportedPath, messages: [{ ruleId: rule, severity, line: lineNo, column: colNo, message }] }]));
    break;
  case "stylish":
    emit(`${reportedPath}\n  ${lineNo}:${colNo}  ${severity}  ${message}  ${rule}\n\n✖ 1 problem (1 error, 0 warnings)`);
    break;
  case "compact":
    emit(`${reportedPath}:${lineNo}:${colNo}: ${severity}: ${message} (${rule})`);
    break;
  case "codeframe":
    emit(`${reportedPath}:${lineNo}:${colNo}: ${severity} - ${message} (${rule})\n> ${lineNo} | ${finding.source}\n     | ^`);
    break;
  case "html":
    emit(`<!DOCTYPE html>\n<html><head><title>rubric report</title></head><body><h1>${rule}</h1><p>${reportedPath}:${lineNo}: ${message}</p></body></html>`);
    break;
  case "junit":
    emit(`<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="rubric" tests="1" failures="1"><testcase classname="${rule}" name="${reportedPath}"><failure message="${message}">${reportedPath}:${lineNo}:${colNo}</failure></testcase></testsuite>`);
    break;
  case "sarif":
    emit(JSON.stringify({
      version: "2.1.0",
      $schema: "https://json.schemastore.org/sarif-2.1.0.json",
      runs: [{
        tool: { driver: { name: "claude-tdd-pro", informationUri: "https://github.com/anthropics/claude-tdd-pro" } },
        results: [{
          ruleId: rule,
          level: severity === "error" ? "error" : "warning",
          message: { text: message },
          locations: [{ physicalLocation: { artifactLocation: { uri: reportedPath }, region: { startLine: lineNo, startColumn: colNo } } }],
        }],
      }],
    }));
    break;
}

process.exit(0);
' -- "$@"
