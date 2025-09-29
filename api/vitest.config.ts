import { defineConfig } from "vitest/config";

const MIN = Number(process.env.COVERAGE_THRESHOLD ?? 80);

export default defineConfig({
  test: {
    coverage: {
      reportsDirectory: "coverage",
      reporter: ["json","html","lcov","text-summary"],
      thresholds: {
        lines: MIN,
        statements: MIN,
        functions: MIN,
        branches: Math.max(MIN - 10, 0),
      },
    },
  },
});