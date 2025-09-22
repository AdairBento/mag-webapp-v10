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
      all: true, // <— conta também os não exercitados
      include: ["src/**/*.ts"],
      exclude: [
        "src/types/**",
        "**/*.d.ts",

        // Excluídos por enquanto:
        "src/index.ts",
        "src/server.ts",
        "src/http/**",
        "src/routes/**",
        "src/middleware/**",
        "src/services/**",
      ],
      reportsDirectory: "coverage",
      reporter: ["text", "html", "lcov"],
      // thresholds: { lines: 50, functions: 50, branches: 40, statements: 50 },
    },
  },
});
