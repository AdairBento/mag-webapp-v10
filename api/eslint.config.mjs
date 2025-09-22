// api/eslint.config.mjs
import tseslint from "typescript-eslint";

export default [
  // Ignora build, deps e arquivos JS/CJS/MJS
  { ignores: ["dist/**", "node_modules/**", "coverage/**", "**/*.{js,cjs,mjs}"] },

  // Regras recomendadas do TS com type-check
  ...tseslint.configs.recommendedTypeChecked,

  // Escopo e regras para .ts
  {
    files: ["src/**/*.ts"],
    languageOptions: {
      parserOptions: {
        project: "./tsconfig.json",
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      // se quiser: "@typescript-eslint/no-namespace": "off",
    },
  },
];
