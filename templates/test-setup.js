// Vitest global setup. Loaded once per test file via setupFiles in
// vitest.config.js.

// jest-dom matchers: toBeInTheDocument, toBeDisabled, toHaveAttribute,
// toHaveTextContent, toHaveClass, toHaveStyle, toHaveValue, toHaveFocus,
// etc. Without these, strict assertions fall back to brittle DOM
// inspection.
import '@testing-library/jest-dom/vitest';

import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';

// Vitest with globals:false doesn't auto-cleanup between tests. Without
// this hook, renders accumulate in the DOM and screen.getBy* sees
// duplicates from previous tests, producing false-positive
// "found multiple elements" failures across test files.
afterEach(() => {
  cleanup();
});
