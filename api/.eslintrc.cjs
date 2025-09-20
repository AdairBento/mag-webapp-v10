
module.exports = {
  root: true,
  env: { es2022: true, node: true },
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'import'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended', 'prettier'],
  parserOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  rules: {
    'import/order': ['warn', { alphabetize: { order: 'asc', caseInsensitive: true } }]
  }
};
