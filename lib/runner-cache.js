// Extracted from rubric/runner.sh: cache lookup using content-addressed
// hash of (spec_command + tree_sha + expectations). Per Musk + Fowler:
// the inline node-e blobs are tech debt; this is the migration target.

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const CACHE_DIR =
  process.env.CACHE_DIR ||
  path.join(process.env.HOME || '/tmp', '.cache', 'claude-tdd-pro');

/**
 * Compute the content-addressed cache key for a spec.
 * @param {object} spec    parsed spec object (name, command, expect)
 * @param {string} treeSha substrate hash for the current tree
 * @returns {string} 16-char hex digest
 */
function cacheKey(spec, treeSha) {
  const h = crypto.createHash('sha256');
  h.update(spec.command || '');
  h.update(treeSha || '');
  h.update(JSON.stringify(spec.expect || {}));
  return h.digest('hex').slice(0, 16);
}

/** Return true if a cache marker exists for the given spec/tree pair. */
function lookup(spec, treeSha) {
  const key = cacheKey(spec, treeSha);
  return fs.existsSync(path.join(CACHE_DIR, key));
}

/** Write a cache marker. Returns the key written. */
function store(spec, treeSha) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const key = cacheKey(spec, treeSha);
  fs.writeFileSync(path.join(CACHE_DIR, key), 'ok');
  return key;
}

if (require.main === module) {
  const op = process.argv[2];
  const specJson = process.env.SPEC_JSON;
  const treeSha = process.env.TREE_SHA;
  if (!op || !specJson) {
    process.stderr.write('runner-cache: usage: <lookup|store> [SPEC_JSON env] [TREE_SHA env]\n');
    process.exit(2);
  }
  const spec = JSON.parse(specJson);
  if (op === 'lookup') {
    process.exit(lookup(spec, treeSha) ? 0 : 1);
  } else if (op === 'store') {
    process.stdout.write(store(spec, treeSha) + '\n');
  } else {
    process.stderr.write(`runner-cache: unknown op: ${op}\n`);
    process.exit(2);
  }
}

module.exports = { cacheKey, lookup, store };
