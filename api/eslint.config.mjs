import tseslint from "typescript-eslint";

export default [
  // Ignora JS/CJS/MJS e pastas de build/deps e scripts
  { ignores: ["dist/**","node_modules/**","coverage/**","**/*.{js,cjs,mjs}",".eslintrc.cjs","prettier.config.cjs","scripts/**"] },

  // Preset sem type-check
  ...tseslint.configs.recommended,

  {
    files: ["src/**/*.ts"],
    // NÃO defina parserOptions.project aqui
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
      "@typescript-eslint/no-namespace": "off",

      // Garante que as regras "tipo chatas" fiquem desligadas
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-misused-promises": "off",
      "@typescript-eslint/no-unnecessary-type-assertion": "off",
      "@typescript-eslint/no-base-to-string": "off"
    }
  }
];
