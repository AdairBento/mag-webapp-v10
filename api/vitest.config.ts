import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reportsDirectory: 'coverage',
      all: false,
      // foque só no que está de fato testado hoje; amplie depois
      include: [
        'src/http/app.ts',
        'src/http/clients.ts',
        'src/middleware/auth.ts',
        'src/utils/math.ts'
      ],
      exclude: [
        '**/*.d.ts',
        'src/types/**',
        'src/**/__mocks__/**',
        'src/server.ts',
        'src/index.ts'
      ],
      thresholds: {
        lines: 11,
        functions: 20,
        branches: 57,
        statements: 11,
      },
    },
  },
});