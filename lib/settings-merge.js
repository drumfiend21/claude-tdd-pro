// Extract from commands/install-hooks.sh — settings.json merge.
// Per Musk + Fowler review: inline node -e blobs are the source of
// the CL-420 env-var bug. Extracted modules have proper imports,
// proper exports, proper test surface.

'use strict';

const fs = require('node:fs');

/**
 * Merge a TDD Pro hooks block into an existing settings.json file.
 * Preserves all operator keys; only overwrites the `hooks` block.
 *
 * @param {string} path        Path to settings.json (will be created if absent)
 * @param {object} hooksBlock  The hooks object to merge in
 * @returns {{merged: boolean, preserved_keys: string[]}}
 */
function mergeSettings(path, hooksBlock) {
  let current = {};
  try { current = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
  const preservedKeys = Object.keys(current).filter((k) => k !== 'hooks');
  current.hooks = Object.assign(current.hooks || {}, hooksBlock);
  fs.writeFileSync(path, JSON.stringify(current, null, 2) + '\n');
  return { merged: true, preserved_keys: preservedKeys };
}

if (require.main === module) {
  const path = process.env.SETTINGS_PATH;
  const hooksJson = process.env.HOOKS_BLOCK;
  if (!path || !hooksJson) {
    process.stderr.write(
      'settings-merge: SETTINGS_PATH and HOOKS_BLOCK env vars required\n',
    );
    process.exit(2);
  }
  const result = mergeSettings(path, JSON.parse(hooksJson));
  process.stdout.write(JSON.stringify(result) + '\n');
}

module.exports = { mergeSettings };
