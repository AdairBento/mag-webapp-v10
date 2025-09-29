import { defineConfig } from "vitest/config";

const MIN = Number(process.env.COVERAGE_THRESHOLD ?? 80);
const defaultIncludeRoots = "http|middleware|utils";
const roots = (process.env.COVERAGE_INCLUDE ?? defaultIncludeRoots)
  .split("|")
  .map((r) => r.replace(/\/+$/, ""));

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage",
      reporter: ["json","html","lcov","text-summary","json-summary"],
      all: false,
      include: roots.map((r) => `${r}/**/*.{ts,tsx,js,jsx}`),
      exclude: [
        "**/*.d.ts",
        "**/*.test.*",
        "**/node_modules/**",
        "**/dist/**",
        "**/coverage/**",
        "**/logs/**",
        "**/.*/**",
        "vitest.config.*",
        "tsconfig.*",
        "eslint.config.*",
        "postman/**",
        "scripts/**",
        "tools/**",
      ],
      thresholds: {
        lines: MIN,
        statements: MIN,
        functions: MIN,
        branches: Math.max(MIN - 10, 0),
      },
    },
  },
});