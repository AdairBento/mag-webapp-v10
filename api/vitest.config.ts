import { defineConfig } from "vitest/config";

const MIN = Number(process.env.COVERAGE_THRESHOLD ?? 80);

// Permite ajustar via env se quiser (ex.: "src|packages/api/src")
const defaultIncludeRoots = "http|middleware|utils";
const roots = (process.env.COVERAGE_INCLUDE ?? defaultIncludeRoots)
  .split("|")
  .map((r) => r.replace(/\/+$/,""));

export default defineConfig({
  test: {
    // Deixa os testes como estão (Vitest descobre **/*.test.*)
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage",
      reporter: ["json","html","lcov","text-summary","json-summary"],
      all: false, // só arquivos tocados/importados pelos testes
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