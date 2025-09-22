import tseslint from "typescript-eslint";

export default [
  // Ignora JS/CJS/MJS e pastas de build/deps e scripts
  { ignores: ["dist/**","node_modules/**","coverage/**","**/*.{js,cjs,mjs}",".eslintrc.cjs","prettier.config.cjs","scripts/**"] },

  // Preset sem type-check
  ...tseslint.configs.recommended,

  // Base para todos os .ts
  {
    files: ["src/**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_", "varsIgnorePattern": "^_" }],
      "@typescript-eslint/no-namespace": "off",

      // Mantém regras que dependem de type-check desligadas
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-misused-promises": "off",
      "@typescript-eslint/no-unnecessary-type-assertion": "off",
      "@typescript-eslint/no-base-to-string": "off"
    }
  },

  // Aqui a gente desliga no-explicit-any SÓ onde precisa
  {
    files: ["src/middleware/**/*.ts", "src/http/**/*.ts", "src/routes/**/*.ts"],
    rules: { "@typescript-eslint/no-explicit-any": "off" }
  },

  // Afrouxa unused APENAS nos dois arquivos citados (inclui Prisma)
  {
    files: ["src/http/insurance.policies.ts", "src/http/notifications.ts"],
    rules: {
      "@typescript-eslint/no-unused-vars": ["warn", {
        "argsIgnorePattern": "^_",
        "varsIgnorePattern": "^(?:_|Prisma|premium|active|startAny|endAny|subject|title|body)$"
      }]
    }
  }
];
