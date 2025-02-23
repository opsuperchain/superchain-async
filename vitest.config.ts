import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globalSetup: './test/integration/setup.ts',
    setupFiles: [],  // Remove setupFiles since we're using globalSetup
    exclude: [
      '**/lib/**/*.test.js',  // Exclude all test files in lib directories
      '**/node_modules/**'    // Exclude all files in node_modules
    ]
  }
}) 