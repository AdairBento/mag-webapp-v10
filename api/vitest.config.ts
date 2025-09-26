import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    exclude: ["**/*.test.js", "**/*.d.ts", "**/*.d.ts.map", "**/node_modules/**", "**/dist/**"],
    setupFiles: ["tests/vitest.setup.ts"],
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text","lcov"],
      include: ["src/http/app.ts","src/middleware/auth.ts","src/utils/math.ts"],
      exclude: ["scripts/**","src/index.ts","src/server.ts","**/*.d.ts"]
    }
  }
});
