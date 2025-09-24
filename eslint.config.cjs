const js = require("@eslint/js");
const globals = require("globals");
const tsParser = require("@typescript-eslint/parser");

/** @type {import("eslint").Linter.FlatConfig[]} */
module.exports = [
  // substitui .eslintignore
  { ignores: ["**/node_modules/**", "**/dist/**", "**/build/**"] },

  // recomendado de JS (NÃO usar spread)
  js.configs.recommended,

  // override para TS sem type-check
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: tsParser,
      parserOptions: { ecmaVersion: "latest", sourceType: "module" },
      globals: globals.node
    },
    rules: {
      // TS cuida disso; evita falsos positivos
      "no-undef": "off",
      // vira warning e ignora nomes iniciados com "_"
      "no-unused-vars": ["warn", {
        varsIgnorePattern: "^_",
        argsIgnorePattern: "^_",
        caughtErrorsIgnorePattern: "^_",
        ignoreRestSiblings: true
      }]
    }
  }
];
