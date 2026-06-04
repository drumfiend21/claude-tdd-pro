// Generalized JSON validator used by several detectors. Extracts the
// inline `node -e 'JSON.parse(...)'` blobs in rubric/detectors/.

'use strict';

const fs = require('node:fs');

/**
 * Validate a JSON file: parses cleanly, optional required-keys check.
 * @param {string} path
 * @param {string[]} requiredKeys
 * @returns {{ valid: boolean, error?: string, missing_keys?: string[] }}
 */
function validateJson(path, requiredKeys = []) {
  let raw;
  try { raw = fs.readFileSync(path, 'utf8'); }
  catch (e) { return { valid: false, error: `read: ${e.message}` }; }

  let obj;
  try { obj = JSON.parse(raw); }
  catch (e) { return { valid: false, error: `parse: ${e.message}` }; }

  if (requiredKeys.length === 0) return { valid: true };

  const missing = requiredKeys.filter((k) => !(k in obj));
  if (missing.length > 0) {
    return { valid: false, missing_keys: missing };
  }
  return { valid: true };
}

if (require.main === module) {
  const path = process.argv[2];
  const keys = process.argv.slice(3);
  if (!path) {
    process.stderr.write('json-validate: usage: <path> [key1] [key2] ...\n');
    process.exit(2);
  }
  const result = validateJson(path, keys);
  process.stdout.write(JSON.stringify(result) + '\n');
  process.exit(result.valid ? 0 : 1);
}

module.exports = { validateJson };
