import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Substitui o 'basic' (deprecado) por 'default' sem summary,
    // que replica o comportamento do basic.
    reporters: [
      ["default", { summary: false }]
    ],
  },
});