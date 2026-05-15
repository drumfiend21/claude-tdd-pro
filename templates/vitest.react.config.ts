// SPDX-License-Identifier: MIT
// Copyright Claude TDD Pro contributors. License: MIT.
//
// vitest.react.config.ts — R-4 react template (per §16 R-4).
// Drop into a React project; pair with size-limit.config.js for
// bundle-budget enforcement and playwright.config.ts for e2e.
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./test-setup.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80,
      },
    },
  },
});
