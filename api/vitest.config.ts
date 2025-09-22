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
      all: false,
      include: ["src/**/*.ts"],
      exclude: [
        "src/types/**",
        "**/*.d.ts",
        "src/index.ts",
        "src/server.ts",
        "src/routes/**",
        "src/middleware/**",
        "src/services/**",
      ],
      reportsDirectory: "coverage",
      reporter: ["text", "html", "lcov"],
      thresholds: { lines: 10, functions: 10, branches: 5, statements: 10 },
    },
  },
});
