import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reportsDirectory: 'coverage',
      // meça só o que nossos testes usam hoje
      include: ['src/http/**', 'src/middleware/**', 'src/utils/**', 'src/services/clients.ts'],
      exclude: [
        '**/*.d.ts',
        'src/types/**',
        'src/**/__mocks__/**',
        'src/server.ts',
        'src/index.ts'
      ],
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 60,
        statements: 70,
      },
    },
  },
});