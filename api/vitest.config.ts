import { defineConfig } from "vitest/config";

const MIN = Number(process.env.COVERAGE_THRESHOLD ?? 80);
const ENFORCE = (process.env.COVERAGE_ENFORCE ?? "0") === "1";
const defaultIncludeRoots = "http|middleware|utils";
const roots = (process.env.COVERAGE_INCLUDE ?? defaultIncludeRoots)
  .split("|")
  .map((r) => r.replace(/\/+$/, ""));

const TH  = ENFORCE ? MIN : 0;
const BR  = ENFORCE ? Math.max(MIN - 10, 0) : 0;

export default defineConfig({
  test: {
    coverage: {
      enabled: true,
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
        lines: TH,
        statements: TH,
        functions: TH,
        branches: BR,
      },
    },
  },
});