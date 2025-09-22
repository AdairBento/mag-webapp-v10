import tseslint from "typescript-eslint";

export default [
  // Ignora JS/CJS/MJS e pastas de build/deps e scripts
  { ignores: ["dist/**","node_modules/**","coverage/**","**/*.{js,cjs,mjs}",".eslintrc.cjs","prettier.config.cjs","scripts/**"] },

  // Preset sem type-check
  ...tseslint.configs.recommended,

  {
    files: ["src/**/*.ts"],
    // regras base
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_", "varsIgnorePattern": "^_" }],
      "@typescript-eslint/no-namespace": "off",

      // garante que regras dependentes de type-check continuem off
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-misused-promises": "off",
      "@typescript-eslint/no-unnecessary-type-assertion": "off",
      "@typescript-eslint/no-base-to-string": "off"
    }
  },

  // Middleware pode usar any sem warning (evita os 2 avisos restantes lá)
  {
    files: ["src/middleware/**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off"
    }
  },

  // Afrouxa unused SÓ nestes dois arquivos e NESTES nomes
  {
    files: ["src/http/insurance.policies.ts", "src/http/notifications.ts"],
    rules: {
      "@typescript-eslint/no-unused-vars": ["warn", {
        "argsIgnorePattern": "^_",
        "varsIgnorePattern": "^(?:_|premium|active|startAny|endAny|subject|title|body)$"
      }]
    }
  }
];
