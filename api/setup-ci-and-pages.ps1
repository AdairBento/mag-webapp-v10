#requires -Version 7
$ErrorActionPreference = 'Stop'

function Tip-Token {
  Write-Host ""
  Write-Host "Se der 401/403:" -ForegroundColor Yellow
  Write-Host " • Verifique se o PAT é REAL e colado por completo." -ForegroundColor Yellow
  Write-Host " • Fine-grained: ative no repositório 'AdairBento/mag-webapp-v10' com:" -ForegroundColor Yellow
  Write-Host "     - Repository permissions: Contents = Read & write; Actions = Read & write; Pages = Read & write" -ForegroundColor Yellow
  Write-Host " • Se sua org usa SSO: em Settings > Developer settings > Tokens > clique 'Enable SSO' para este repo." -ForegroundColor Yellow
  Write-Host ""
}

function Encode-Base64([string]$text) {
  [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
}

# ======== CONFIG ========
$repo   = "AdairBento/mag-webapp-v10"     # owner/repo
$branch = $null                           # se $null, detecta a default branch do repo
$path   = ".github/workflows/ci.yml"
$commit = "ci: setup CI + Pages (via PowerShell)"

# ======== YAML DO WORKFLOW (com pages_check: NÃO precisa de vars.PAGES_ENABLED) ========
$ciYaml = @'
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}-${{ github.event_name }}
  cancel-in-progress: ${{ github.event_name != 'workflow_dispatch' }}

permissions:
  contents: read
  actions: read
  pages: write
  id-token: write

jobs:
  lint:
    name: lint
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: npm
          cache-dependency-path: api/package-lock.json
      - name: Install dependencies
        working-directory: api
        run: npm ci --no-audit --no-fund
      - name: Run lint
        working-directory: api
        run: npm run lint

  test:
    name: Test (Node 20.x)
    runs-on: ubuntu-24.04
    env:
      VITEST_COVERAGE: 1
      COVERAGE_THRESHOLD: 80
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: ".nvmrc"
          cache: npm
          cache-dependency-path: api/package-lock.json
      - name: Install dependencies
        working-directory: api
        run: npm ci --no-audit --no-fund
      - name: Typecheck
        working-directory: api
        run: npm run typecheck
      - name: Run tests with coverage
        working-directory: api
        run: npm test --silent -- --coverage --coverage.reporter=json --coverage.reporter=html --coverage.reporter=lcov
      - name: Upload coverage (lcov)
        uses: actions/upload-artifact@v4
        with:
          name: coverage-lcov
          path: api/coverage/lcov.info
          retention-days: 7
          if-no-files-found: ignore
      - name: Upload coverage (html)
        uses: actions/upload-artifact@v4
        with:
          name: coverage-html
          path: api/coverage
          retention-days: 7
          if-no-files-found: ignore

  pages_check:
    name: Check GitHub Pages enabled
    runs-on: ubuntu-24.04
    outputs:
      enabled: ${{ steps.detect.outputs.enabled }}
    steps:
      - uses: actions/github-script@v7
        id: detect
        with:
          script: |
            try {
              await github.request('GET /repos/{owner}/{repo}/pages', {
                owner: context.repo.owner,
                repo: context.repo.repo
              });
              core.setOutput('enabled', 'true');
            } catch (e) {
              core.info(`GET /pages -> ${e.status || 'error'} (provavelmente Pages desabilitado)`);
              core.setOutput('enabled', 'false');
            }

  publish-coverage:
    name: publish-coverage
    needs: [test, pages_check]
    if: ${{ needs.pages_check.outputs.enabled == 'true' }}
    runs-on: ubuntu-24.04
    concurrency:
      group: pages
      cancel-in-progress: true
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    permissions:
      pages: write
      id-token: write
      actions: read
      contents: read
    steps:
      - name: Download coverage (html)
        uses: actions/download-artifact@v4
        with:
          name: coverage-html
          path: ./coverage
      - name: Setup GitHub Pages
        uses: actions/configure-pages@v5
      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./coverage
      - name: Deploy to GitHub Pages
        id: deploy
        uses: actions/deploy-pages@v4
'@

# ======== TOKEN ========
Write-Host "Cole seu GitHub PAT (fine-grained ou classic). O input fica oculto:" -ForegroundColor Cyan
$sec = Read-Host -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try { $pat = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
$pat = ($pat ?? "").Trim()
if ([string]::IsNullOrWhiteSpace($pat)) { throw "Nenhum token informado." }

# Headers corretos: use "token", não "Bearer", para PAT
$h = @{
  Authorization          = "token $pat"
  Accept                 = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
  "User-Agent"           = "ps-setup-ci-pages"
}

# ======== 0) Checa acesso ao repo e detecta default branch ========
Write-Host "`n== 0) Verificando acesso ao repositório ==" -ForegroundColor Cyan
$repoUrl = "https://api.github.com/repos/$repo"
try {
  $repoInfo = Invoke-RestMethod -Uri $repoUrl -Headers $h -Method GET
  Write-Host ("OK: " + $repoInfo.full_name) -ForegroundColor Green
  if (-not $branch -or [string]::IsNullOrWhiteSpace($branch)) {
    $branch = $repoInfo.default_branch
    Write-Host ("Default branch detectada: " + $branch) -ForegroundColor DarkGray
  }
} catch {
  Tip-Token
  throw "Falha ao acessar $repo (401/403)."
}

# ======== 1) Upsert do workflow (contents API) ========
Write-Host "`n== 1) Criando/atualizando $path ==" -ForegroundColor Cyan
$contentsUrl = "https://api.github.com/repos/$repo/contents/$($path -replace '\\','/')"
$sha = $null
try { $sha = (Invoke-RestMethod -Uri $contentsUrl -Headers $h -Method GET).sha } catch {}
$body = @{ message = $commit; content = (Encode-Base64 $ciYaml); branch = $branch }
if ($sha) { $body.sha = $sha }
try {
  Invoke-RestMethod -Uri $contentsUrl -Headers $h -Method PUT -Body ($body | ConvertTo-Json -Depth 10) | Out-Null
  Write-Host "Workflow salvo com sucesso." -ForegroundColor Green
} catch {
  $msg = $_.ErrorDetails.Message
  if ($msg -match 'Resource not accessible by personal access token' -or $_.Exception.Response.StatusCode.value__ -eq 403) {
    Tip-Token
    throw "Seu PAT não tem 'Contents: Read & write' no repositório."
  }
  throw
}

# ======== 2) Habilita Pages (build_type=workflow) ========
Write-Host "`n== 2) Habilitando GitHub Pages (build_type=workflow) ==" -ForegroundColor Cyan
$pagesUrl = "https://api.github.com/repos/$repo/pages"
$pagesEnabled = $false
try {
  $resp = Invoke-RestMethod -Uri $pagesUrl -Headers $h -Method GET
  if ($resp.build_type -ne 'workflow') {
    Invoke-RestMethod -Uri $pagesUrl -Headers $h -Method PUT -Body (@{ build_type = 'workflow' } | ConvertTo-Json) | Out-Null
  }
  $pagesEnabled = $true
} catch {
  $code = $_.Exception.Response.StatusCode.value__
  if ($code -eq 404) {
    try {
      Invoke-RestMethod -Uri $pagesUrl -Headers $h -Method POST -Body (@{ build_type = 'workflow' } | ConvertTo-Json) | Out-Null
      $pagesEnabled = $true
    } catch {
      $msg = $_.ErrorDetails.Message
      if ($msg -match 'Resource not accessible by personal access token' -or $_.Exception.Response.StatusCode.value__ -eq 403) {
        Tip-Token
        throw "Seu PAT precisa 'Pages: Read & write' e permissão ADMIN no repo para habilitar Pages."
      }
      throw
    }
  } elseif ($code -eq 403) {
    Tip-Token
    throw "Sem permissão para habilitar Pages (precisa Pages: RW e permissão admin no repo)."
  } else {
    throw
  }
}
Write-Host ("GitHub Pages: " + ($(if($pagesEnabled){'habilitado/ajustado'}else{'não habilitado'}))) -ForegroundColor Green

# ======== 3) Dispara o workflow (opcional, sempre tentamos) ========
Write-Host "`n== 3) Disparando o workflow (workflow_dispatch) ==" -ForegroundColor Cyan
$wfDispatch = "https://api.github.com/repos/$repo/actions/workflows/ci.yml/dispatches"
try {
  Invoke-RestMethod -Uri $wfDispatch -Headers $h -Method POST -Body (@{ ref = $branch } | ConvertTo-Json) | Out-Null
  Write-Host "Workflow 'CI' disparado na branch '$branch'." -ForegroundColor Green
} catch {
  $msg = $_.ErrorDetails.Message
  if ($msg -match 'Resource not accessible by personal access token' -or $_.Exception.Response.StatusCode.value__ -eq 403) {
    Tip-Token
    Write-Host "Sem permissão para workflow_dispatch (Actions: Read & write). Você pode rodar manualmente na aba Actions." -ForegroundColor Yellow
  } else {
    throw
  }
}

# ======== 4) Dicas finais ========
Write-Host ""
Write-Host "✅ Pronto!" -ForegroundColor Green
Write-Host "• Abra a aba 'Actions' do repositório e acompanhe o workflow 'CI'." -ForegroundColor DarkGray
Write-Host "• Se o Pages estiver habilitado, o job 'publish-coverage' publicará a cobertura em GitHub Pages." -ForegroundColor DarkGray
Write-Host "• A URL final aparece no summary do job 'Deploy to GitHub Pages' (step 'deploy')." -ForegroundColor DarkGray
