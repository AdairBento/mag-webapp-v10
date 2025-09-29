import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname  = dirname(__filename);
const ROOT = resolve(__dirname); // garante root = api/

const MIN = Number(process.env.COVERAGE_THRESHOLD ?? 80);

// Pastas-alvo por padrão. Pode mudar em CI via COVERAGE_INCLUDE="http|middleware|utils"
const defaultIncludeRoots = "http|middleware|utils";
const roots = (process.env.COVERAGE_INCLUDE ?? defaultIncludeRoots)
  .split("|")
  .map((r) => r.replace(/\/+$/, ""));

// GLOBS de include relativos ao root (api/), considerando "src/<módulo>/..."
const INCLUDE = roots.map((r) => `src/${r}/**/*.{ts,tsx,js,jsx}`);

export default defineConfig({
  root: ROOT,
  test: {
    include: ["tests/**/*.test.{ts,tsx,js,jsx}"],
    environment: "node",
    coverage: {
      enabled: !!process.env.VITEST_COVERAGE,   // ativa no CI
      provider: "v8",
      reportsDirectory: "coverage",
      reporter: ["json","html","lcov","text-summary","json-summary"],
      all: false,                               // só arquivos exercitados (suficiente p/ meta global)
      include: INCLUDE,
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