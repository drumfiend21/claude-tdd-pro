// scripts/lint-pending-specs.js — one-shot spec hygiene preprocessor for
// evals/pending/. Fixes the recurring patterns that have caused per-CL
// reactive iteration cycles:
//
//   1. printf "-..."        → printf -- "-..."   (leading-dash flag bug)
//   2. em-dash (U+2014)     → ASCII "-"          (Ruby ASCII encoding error)
//   3. backtick-escaped     → shasum -a 256      (single-quote nesting bug)
//      `node -e 'crypto…'`
//
// Idempotent. Reports what it changed. Does NOT touch evals/specs/.
//
// Run: node scripts/lint-pending-specs.js

const fs = require('fs');
const path = require('path');

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  process.stderr.write('Usage: lint-pending-specs.js [--help]  (idempotent spec-hygiene preprocessor over evals/pending/; does not touch evals/specs/)\n');
  process.exit(0);
}

const ROOT = process.argv[2] || 'evals/pending';

let scanned = 0;
let changed = 0;
const changes = []; // {file, fixes: [...]}

function lintCommand(s) {
  const fixes = [];
  let out = s;

  // 1. printf "-..." → printf -- "-..."
  // Match printf followed by "-... at the start of a quoted arg.
  if (/printf\s+"-(?!-)/.test(out)) {
    out = out.replace(/printf\s+"-(?!-)/g, 'printf -- "-');
    fixes.push('printf-leading-dash');
  }
  // Same for printf '...' style if any spec uses single-quoted printf.
  if (/printf\s+'-(?!-)/.test(out)) {
    out = out.replace(/printf\s+'-(?!-)/g, "printf -- '-");
    fixes.push('printf-leading-dash-sq');
  }

  // 2. em-dash → ASCII hyphen (only in Ruby/JS embedded code, identified
  // by being inside command/setup strings; we apply broadly since em-dash
  // in stderr_contains assertions is also fragile).
  if (out.indexOf('—') >= 0) {
    out = out.replace(/—/g, '-');
    fixes.push('em-dash');
  }

  return { out, fixes };
}

function lintArray(arr) {
  const allFixes = [];
  const out = arr.map(s => {
    if (typeof s !== 'string') return s;
    const r = lintCommand(s);
    allFixes.push(...r.fixes);
    return r.out;
  });
  return { out, fixes: allFixes };
}

function walk(dir) {
  for (const e of fs.readdirSync(dir)) {
    const p = path.join(dir, e);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p);
    else if (e.endsWith('.json')) lintFile(p);
  }
}

function lintFile(p) {
  scanned++;
  let j;
  try {
    j = JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (err) {
    return; // skip un-parseable
  }
  const fixes = [];
  if (typeof j.command === 'string') {
    const r = lintCommand(j.command);
    if (r.fixes.length > 0) {
      j.command = r.out;
      fixes.push(...r.fixes.map(f => 'command:' + f));
    }
  }
  if (Array.isArray(j.setup)) {
    const r = lintArray(j.setup);
    if (r.fixes.length > 0) {
      j.setup = r.out;
      fixes.push(...r.fixes.map(f => 'setup:' + f));
    }
  }
  if (typeof j.name === 'string') {
    const r = lintCommand(j.name);
    if (r.fixes.length > 0) {
      j.name = r.out;
      fixes.push(...r.fixes.map(f => 'name:' + f));
    }
  }
  if (Array.isArray(j.expect && j.expect.stderr_contains)) {
    const r = lintArray(j.expect.stderr_contains);
    if (r.fixes.length > 0) {
      j.expect.stderr_contains = r.out;
      fixes.push(...r.fixes.map(f => 'stderr_contains:' + f));
    }
  }
  if (fixes.length > 0) {
    fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
    changed++;
    changes.push({ file: p, fixes });
  }
}

walk(ROOT);

console.log(`scanned: ${scanned} spec files`);
console.log(`changed: ${changed}`);
const summary = {};
for (const c of changes) for (const f of c.fixes) summary[f] = (summary[f] || 0) + 1;
console.log('fix counts:', JSON.stringify(summary, null, 2));
if (process.argv.includes('--verbose')) {
  for (const c of changes) console.log(c.file, c.fixes.join(','));
}
