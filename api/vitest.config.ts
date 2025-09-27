import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    exclude: ['**/*.test.js', '**/*.d.ts', '**/node_modules/**', '**/dist/**'],
    setupFiles: ['tests/vitest.setup.ts'],
    environment: 'node',
    coverage: {
      provider: 'v8',
      enabled: process.env.CI === 'true' || process.env.VITEST_COVERAGE === '1',
      reporter: ['text', 'html', 'lcov'],
      reportsDirectory: join(__dirname, 'coverage'),
      // ⚠️ medir só os alvos atuais (expandimos depois)
      include: ['src/http/app.ts', 'src/middleware/auth.ts', 'src/utils/math.ts'],
      exclude: ['scripts/**', 'src/index.ts', 'src/server.ts', '**/*.d.ts'],
      thresholds: { lines: 95, functions: 95, branches: 80, statements: 95 }
    }
  }
});


