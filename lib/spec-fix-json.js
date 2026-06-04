// Extract of /tmp/fix-json.js. Now a proper module under lib/ that
// the orchestrator imports rather than rewriting per session.

'use strict';

const fs = require('node:fs');
const path = require('node:path');

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const e of fs.readdirSync(dir)) {
    const p = path.join(dir, e);
    const st = fs.statSync(p);
    if (st.isDirectory()) out.push(...walk(p));
    else if (e.endsWith('.json')) out.push(p);
  }
  return out;
}

/**
 * Repair malformed JSON spec files produced by heredoc generators.
 * Specifically targets the unescaped-quote and \$ → $ patterns
 * that caused CL-414 / CL-415 retries.
 *
 * @param {string} dir Root directory to scan
 * @returns {{fixed: number, failed: number, files: string[]}}
 */
function repair(dir) {
  let fixed = 0;
  let failed = 0;
  const filesFixed = [];
  for (const p of walk(dir)) {
    const raw = fs.readFileSync(p, 'utf8');
    try { JSON.parse(raw); continue; } catch {}

    const nameM = raw.match(/^\s*"name":\s*"((?:[^"\\]|\\.)*?)"\s*,?\s*$/m);
    const cmdM = raw.match(
      /^\s*"command":\s*"([\s\S]*?)"\s*,\s*$\s*"setup":/m,
    );
    const setupM = raw.match(/"setup":\s*(\[[^\]]*\])/);
    const expectM = raw.match(/"expect":\s*({[^}]*})/);
    if (!nameM || !cmdM) { failed++; continue; }

    const obj = {
      name: nameM[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\'),
      command: cmdM[1].replace(/\\"/g, '"').replace(/\\\\/g, '\\'),
      setup: setupM ? JSON.parse(setupM[1]) : [],
      expect: expectM
        ? JSON.parse(expectM[1].replace(/(['"])([^'"]+)(['"])/g, '"$2"'))
        : {},
    };
    fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
    fixed++;
    filesFixed.push(p);
  }
  return { fixed, failed, files: filesFixed };
}

if (require.main === module) {
  const dir = process.argv[2];
  if (!dir) {
    process.stderr.write('spec-fix-json: usage: <dir>\n');
    process.exit(2);
  }
  const result = repair(dir);
  process.stdout.write(`fixed=${result.fixed} failed=${result.failed}\n`);
}

module.exports = { repair, walk };
