// Vitest config — React projects with strict cleanup discipline.
//
// Required deps:
//   npm i -D vitest jsdom @vitejs/plugin-react @testing-library/react \
//            @testing-library/jest-dom @testing-library/user-event

import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  // JSX in test files needs the React transform. Without it tests throw
  // "React is not defined".
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: false,
    include: ['src/**/*.{test,spec}.{js,jsx,ts,tsx}', 'tests/**/*.{test,spec}.{js,jsx,ts,tsx}'],
    // jest-dom matchers AND afterEach(cleanup) registered here. Without
    // cleanup, vitest with globals:false leaks DOM across tests and
    // screen.getBy* sees duplicates from previous tests.
    setupFiles: ['./src/__tests__/setup.js'],
    coverage: {
      reporter: ['text', 'html'],
      include: ['src/**/*.{js,jsx,ts,tsx}'],
      exclude: ['**/*.test.*', '**/*.spec.*', '**/node_modules/**', 'src/**/*.d.ts'],
    },
  },
});
