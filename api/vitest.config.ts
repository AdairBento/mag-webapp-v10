import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    passWithNoTests: true,
    include: ["**/*.{test,spec}.?(c|m)[jt]s?(x)"],
    exclude: [
      "node_modules/**",
      "dist/**",
      "cypress/**",
      "**/.{idea,git,cache,output,temp}/**",
      "**/{karma,rollup,webpack,vite,vitest,jest,ava,babel,nyc,cypress,tsup,build,eslint,prettier}.config.*",
    ],
    coverage: {
      enabled: true,
      provider: "v8",
      all: true, // reporta também arquivos não exercitados
      include: ["src/**/*.ts"], // só código-fonte
      exclude: ["src/types/**", "**/*.d.ts"],
      reportsDirectory: "coverage",
      reporter: ["text", "html", "lcov"],
      // (opcional) quebras mínimas para falhar o CI:
      // thresholds: { lines: 50, functions: 50, branches: 40, statements: 50 },
    },
  },
});
