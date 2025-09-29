# QA / Como rodar

## Local (Windows/PowerShell)
1. Rodar testes + cobertura:
   - Da **raiz**: 
pm --prefix api run test:cov
   - Ou **dentro de api/**: 
pm run test:cov
2. Abrir relatório HTML: start .\api\coverage\index.html
3. Ranking (piores por branches): .\tools\coverage-rank.ps1

## CI
- Workflow: .github/workflows/ci.yml (Node 20, lint, typecheck, test + coverage).
- Artefato: **coverage-html** com o relatório completo.
- Variáveis de cobertura configuráveis via env: VITEST_COVERAGE, COVERAGE_THRESHOLD, COVERAGE_INCLUDE.

## Dicas
- Evite quebrar o comando do Vitest em várias linhas quando usar --coverage.reporter=....
- Se mudar COVERAGE_INCLUDE/THRESHOLD, o cache do turbo é invalidado (configurado em tasks.test.env).