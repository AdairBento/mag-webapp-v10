import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    exclude: ['**/*.test.js', '**/*.d.ts', '**/*.d.ts.map', '**/node_modules/**', '**/dist/**'],
    setupFiles: ['tests/vitest.setup.ts'],
    environment: 'node'
  }
})
