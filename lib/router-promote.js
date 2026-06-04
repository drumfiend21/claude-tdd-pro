#!/usr/bin/env node
// P-10 eval-driven router promotion (§6 P-10 + §24 v1.10 amendment).
//
// Reads P-2 eval datasets at evals/datasets/agents/*.jsonl, computes
// per-(model, task-class) pass rates, and emits an updated
// prompts/router.yaml where each route carries an `eval_score:`
// field reflecting the most recent eval pass rate.
//
// This upgrades P-10 from a static config (model selected by
// hand-set rationale) to an eval-driven dispatch (model selected
// because the eval suite says it wins for that task-class).
//
// Usage:
//   node lib/router-promote.js [--router prompts/router.yaml]
//                              [--datasets evals/datasets/agents/]
//                              [--out prompts/router.yaml]
//                              [--dry-run]
//
// Output: updated router.yaml with eval_score per route.
//
// Exit:
//   0 — updated (or dry-run plan emitted)
//   2 — usage error

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const PLUGIN_ROOT =
  process.env.CLAUDE_PLUGIN_ROOT ||
  path.resolve(__dirname, '..');

function parseArgs(argv) {
  const args = {
    router: path.join(PLUGIN_ROOT, 'prompts', 'router.yaml'),
    datasets: path.join(PLUGIN_ROOT, 'evals', 'datasets', 'agents'),
    out: '',
    dryRun: false,
  };
  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case '--router': args.router = argv[++i]; break;
      case '--datasets': args.datasets = argv[++i]; break;
      case '--out': args.out = argv[++i]; break;
      case '--dry-run': args.dryRun = true; break;
      case '-h':
      case '--help':
        process.stderr.write(
          'Usage: router-promote.js [--router <yaml>] [--datasets <dir>] ' +
          '[--out <yaml>] [--dry-run]\n',
        );
        process.exit(0);
      default:
        process.stderr.write(`router-promote: unknown arg: ${argv[i]}\n`);
        process.exit(2);
    }
  }
  if (!args.out) args.out = args.router;
  return args;
}

function readJsonl(filePath) {
  if (!fs.existsSync(filePath)) return [];
  return fs
    .readFileSync(filePath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      try { return JSON.parse(line); } catch { return null; }
    })
    .filter(Boolean);
}

function scorePerModelAndTaskClass(datasetsDir) {
  const scores = {}; // { task_class: { model: { passed, total } } }
  if (!fs.existsSync(datasetsDir)) return scores;
  for (const entry of fs.readdirSync(datasetsDir)) {
    if (!entry.endsWith('.jsonl')) continue;
    const taskClass = entry.replace(/\.jsonl$/, '');
    scores[taskClass] = scores[taskClass] || {};
    for (const row of readJsonl(path.join(datasetsDir, entry))) {
      const model = row.model || row.expected_model || 'unknown';
      const passed = row.pass === true || row.passed === true ? 1 : 0;
      scores[taskClass][model] = scores[taskClass][model] || {
        passed: 0, total: 0,
      };
      scores[taskClass][model].total += 1;
      scores[taskClass][model].passed += passed;
    }
  }
  return scores;
}

function emitRouterYaml(currentYaml, scores) {
  // Minimal YAML editor: append/overwrite the `eval_score:` field
  // on each route block. Preserves all other content.
  const lines = currentYaml.split('\n');
  const out = [];
  let currentTaskClass = '';
  let currentModel = '';
  let inRoutes = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^routes:/.test(line)) inRoutes = true;
    const tc = line.match(/^\s*-\s*task_class:\s*(\S+)/);
    if (tc) { currentTaskClass = tc[1]; currentModel = ''; }
    const mm = line.match(/^\s*model:\s*(\S+)/);
    if (mm) currentModel = mm[1];

    // Replace existing eval_score line OR insert new one after rationale
    if (/^\s*eval_score:/.test(line)) continue;

    out.push(line);

    if (inRoutes && /^\s*rationale:/.test(line) &&
        currentTaskClass && currentModel) {
      const cell = scores?.[currentTaskClass]?.[currentModel];
      if (cell && cell.total > 0) {
        const rate = (cell.passed / cell.total).toFixed(3);
        const indent = (line.match(/^(\s*)/) || [''])[0];
        out.push(
          `${indent}eval_score: ${rate}  # ${cell.passed}/${cell.total} on ${currentTaskClass}`,
        );
      } else {
        const indent = (line.match(/^(\s*)/) || [''])[0];
        out.push(
          `${indent}eval_score: null  # no P-2 dataset for ${currentTaskClass} / ${currentModel}`,
        );
      }
    }
  }
  return out.join('\n');
}

function main() {
  const args = parseArgs(process.argv);
  if (!fs.existsSync(args.router)) {
    process.stderr.write(`router-promote: router not found: ${args.router}\n`);
    process.exit(2);
  }

  const currentYaml = fs.readFileSync(args.router, 'utf8');
  const scores = scorePerModelAndTaskClass(args.datasets);
  const updated = emitRouterYaml(currentYaml, scores);

  if (args.dryRun) {
    process.stderr.write(
      `router-promote: dry-run; would write ${updated.length} bytes to ${args.out}\n`,
    );
    process.exit(0);
  }

  fs.writeFileSync(args.out, updated);
  const taskClasses = Object.keys(scores).length;
  process.stderr.write(
    `router-promote: scored ${taskClasses} task-class(es) from P-2 datasets; wrote ${args.out}\n`,
  );
}

if (require.main === module) main();
module.exports = { scorePerModelAndTaskClass, emitRouterYaml };
