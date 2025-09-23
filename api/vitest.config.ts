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
    setupFiles: ["tests/vitest.setup.ts"],
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
        "src/services/**",
      ],
      reportsDirectory: "coverage",
      reporter: ["text", "html", "lcov"],
    },
  },
});
