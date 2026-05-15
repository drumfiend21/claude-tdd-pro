// SPDX-License-Identifier: MIT
// Copyright Claude TDD Pro contributors. License: MIT.
//
// size-limit.config.js — R-4 react template (per §16 R-4).
// Per-route bundle budgets enforce g-react-008 (bundle-size budget
// per route). Adjust limits per project; the defaults aim at LCP
// and INP targets for typical Next.js app-router shells.
module.exports = [
  {
    name: "app shell (first load)",
    path: "dist/_next/static/chunks/main-*.js",
    limit: "120 kb",
  },
  {
    name: "route: /",
    path: "dist/_next/static/chunks/pages/index-*.js",
    limit: "180 kb",
  },
  {
    name: "route: /dashboard",
    path: "dist/_next/static/chunks/pages/dashboard-*.js",
    limit: "250 kb",
  },
  {
    name: "route: /settings",
    path: "dist/_next/static/chunks/pages/settings-*.js",
    limit: "200 kb",
  },
];
