// Extracted spec classifier used by audit-spec-depth.sh. Documents
// the classification taxonomy so the fitness function's behavior is
// inspectable and tested.

'use strict';

/**
 * Classify a spec command string as one of:
 *   - 'behavior'   invokes substrate (bash/node $CLAUDE_PLUGIN_ROOT/...)
 *   - 'shape'      grep-only assertion on file content
 *   - 'existence'  [ -s file ] style existence check
 *   - 'other'      anything else
 *
 * @param {string} cmd
 * @returns {'behavior'|'shape'|'existence'|'other'}
 */
function classify(cmd) {
  const invokesSubstrate =
    /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*/.test(cmd) ||
    /\|\s*(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT/.test(cmd);
  if (invokesSubstrate) return 'behavior';
  const isGrep = /grep\s+-[a-zE]*q/.test(cmd);
  if (isGrep) return 'shape';
  const isExistence = /\[\s*-[sefxd]\s+["]?\$CLAUDE_PLUGIN_ROOT/.test(cmd);
  if (isExistence) return 'existence';
  return 'other';
}

/**
 * Return true when the spec's command explicitly invokes an
 * executable substrate file (`bash $X.sh ...` or `node $X.js ...`
 * or `bash $X/<extension-less-binary>`).
 */
function hasExecSubstrate(cmd) {
  return (
    /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*\.(sh|js)/.test(cmd) ||
    /(bash|node)\s+["]?\$CLAUDE_PLUGIN_ROOT[^"\s]*\/[a-zA-Z][a-zA-Z0-9_-]+["\s]/.test(
      cmd,
    )
  );
}

module.exports = { classify, hasExecSubstrate };
