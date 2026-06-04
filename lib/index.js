// Public module surface for claude-tdd-pro's JS helpers. Per
// Musk + Fowler review: inline `node -e '...'` blobs are tech debt.
// This module is the migration target.

'use strict';

module.exports = {
  settingsMerge: require('./settings-merge'),
  specFixJson:   require('./spec-fix-json'),
  specClassifier: require('./spec-classifier'),
  routerPromote: require('./router-promote'),
};
