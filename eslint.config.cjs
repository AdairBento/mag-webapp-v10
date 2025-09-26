const js = require("@eslint/js");
const globals = require("globals");
const tsParser = require("@typescript-eslint/parser");
const tsPlugin = require("@typescript-eslint/eslint-plugin");

/** @type {import("eslint").Linter.FlatConfig[]} */
module.exports = [
  { ignores: ['**/node_modules/**','**/dist/**','**/build/**','api/.eslintrc.cjs'] },
  // Substitui .eslintignore
  { ignores: ["**/node_modules/**", "**/dist/**", "**/build/**"] },

  // Regras JS recomendadas (sem spread do array principal)
  js.configs.recommended,

  // TS (sem type-check no lint) + regras de unused via @typescript-eslint
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: tsParser,
      parserOptions: { ecmaVersion: "latest", sourceType: "module" },
      globals: globals.node,
    },
    plugins: { "@typescript-eslint": tsPlugin },
    rules: {
      // Evita falsos positivos em TS
      "no-undef": "off",
      // Use a versão TS-aware e silencie a core
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": ["warn", {
        "varsIgnorePattern": "^_",
        "argsIgnorePattern": "^_",
        "caughtErrorsIgnorePattern": "^_",
        "ignoreRestSiblings": true
      }]
    }
  }
];


