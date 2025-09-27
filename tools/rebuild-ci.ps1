@'
<# Rebuild-CI — refaz workflow CI, opcionalmente desabilita legados, dispara run e abre coverage #>
[CmdletBinding()]
param(
  [switch]$DisableApiCi,    # move o workflow "api-ci (lint + typecheck + test)" para backup
  [switch]$Push,            # git add/commit/push
  [switch]$Run,             # dispara workflow e aguarda concluir
  [switch]$Open,            # abre o relatório HTML ao fim
  [string]$CommitMessage = 'ci: rebuild CI (codecov v5, merge robusto, slack condicional) + tools:get-coverage v2',
  [int]$CoverageThreshold = 80
)

$ErrorActionPreference = 'Stop'
function Log([string]$m){ Write-Host "[$(Get-Date -Format HH:mm:ss)] $m" }

try { & git --version | Out-Null } catch { throw "git não encontrado." }
try { & gh --version | Out-Null } catch { throw "GitHub CLI (gh) não encontrado." }
if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "rode dentro de um repositório git." }

# paths
$wfDir = ".github/workflows"
$wfFile = Join-Path $wfDir "ci.yml"
$backupDir = Join-Path $wfDir ("_backup\" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$toolsDir = "tools"
$getCov = Join-Path $toolsDir "get-coverage.ps1"

New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

if (Test-Path $wfFile) {
  Copy-Item $wfFile (Join-Path $backupDir "ci.yml.bak") -Force
  Log "Backup: $backupDir\ci.yml.bak"
}

# --- conteúdo do CI (usa placeholder de threshold para evitar conflitos com ${{ }} do GitHub)
$ciYaml = @'
name: CI

on:
  workflow_dispatch:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  id-token: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  COVERAGE_THRESHOLD: __THRESHOLD__

jobs:
  lint:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          cache: npm
          cache-dependency-path: api/package-lock.json
      - run: npm ci --no-audit --no-fund
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        node: [18.x, 20.x]
    name: Test (Node ${{ matrix.node }})
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: npm
          cache-dependency-path: api/package-lock.json
      - run: npm ci --no-audit --no-fund
      - run: npm run typecheck
      - run: npm test --silent -- --coverage
      - name: Upload coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: api-coverage-${{ matrix.node }}
          path: api/coverage
          retention-days: 7
          overwrite: true
          if-no-files-found: warn

  sca-sast:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20.x'
          cache: npm
          cache-dependency-path: api/package-lock.json
      - run: npm ci --no-audit --no-fund
      - run: npm audit --audit-level=moderate
      - name: Run ESLint for SAST
        run: npm run lint

  merge-coverage-report:
    needs: [test]
    runs-on: ubuntu-latest
    steps:
      - name: Download coverage (Node 18.x)
        uses: actions/download-artifact@v4
        with:
          name: api-coverage-18.x
          path: ./coverage-ci/node18

      - name: Download coverage (Node 20.x)
        uses: actions/download-artifact@v4
        with:
          name: api-coverage-20.x
          path: ./coverage-ci/node20

      - name: List downloaded coverage files (debug)
        run: ls -R coverage-ci

      - name: Merge coverage JSON + gerar HTML/JSON-SUMMARY/LCOV
        shell: bash
        run: |
          set -euo pipefail
          mkdir -p coverage-ci/merge-input coverage-ci/merged coverage-ci/merged-html
          shopt -s globstar nullglob
          i=0
          for f in coverage-ci/**/coverage-final.json; do
            cp "$f" "coverage-ci/merge-input/coverage-$((++i)).json"
          done
          if [ $i -eq 0 ]; then
            echo "Nenhum coverage-final.json encontrado"; exit 1
          fi
          npx nyc@15.1.0 merge coverage-ci/merge-input coverage-ci/merged/coverage.json
          npx nyc@15.1.0 report --temp-dir=coverage-ci/merged --reporter=html        --report-dir=coverage-ci/merged-html
          npx nyc@15.1.0 report --temp-dir=coverage-ci/merged --reporter=json-summary --report-dir=coverage-ci/merged-html
          npx nyc@15.1.0 report --temp-dir=coverage-ci/merged --reporter=lcovonly    --report-dir=coverage-ci/merged

      - name: Extrair % cobertura (lines)
        id: cov
        run: |
          node -e "const fs=require('fs');const p='coverage-ci/merged-html/coverage-summary.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));fs.appendFileSync(process.env.GITHUB_OUTPUT,`pct=${j.total.lines.pct}\n`);"

      - name: Enforce threshold (${{ env.COVERAGE_THRESHOLD }}%)
        run: |
          node -e "const p=Number(process.env.PCT)||0,const_th=Number(process.env.THRESHOLD)||80; if(p<const_th){console.error(`Coverage ${p}% < ${const_th}%`);process.exit(1)} else {console.log(`Coverage ${p}% >= ${const_th}%`)}"
        env:
          PCT: ${{ steps.cov.outputs.pct }}
          THRESHOLD: ${{ env.COVERAGE_THRESHOLD }}

      - name: Upload merged report (HTML)
        uses: actions/upload-artifact@v4
        with:
          name: merged-coverage-report
          path: coverage-ci/merged-html
          retention-days: 7
          overwrite: true

      - name: Upload coverage to Codecov (OIDC)
        if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.fork == false }}
        uses: codecov/codecov-action@v5
        with:
          files: coverage-ci/merged/lcov.info
          fail_ci_if_error: true
          use_oidc: true

      - name: Slack coverage alert
        if: ${{ always() && secrets.SLACK_WEBHOOK_URL != '' }}
        uses: rtCamp/action-slack-notify@v2
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
          SLACK_COLOR: ${{ job.status }}
          SLACK_CUSTOM_PAYLOAD: |
            {"text":"CI Coverage: ${{ steps.cov.outputs.pct }}% (threshold ${{ env.COVERAGE_THRESHOLD }}%). Run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}","unfurl_links":false}

      - name: PR Coverage Comment
        if: github.event_name == 'pull_request'
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          message: |
            ## Coverage Report
            **${{ steps.cov.outputs.pct }}%** (threshold **${{ env.COVERAGE_THRESHOLD }}%**)
            - Artifacts: merged-coverage-report
            - Codecov: uploaded via ${{ github.job }}
'@

# injeta o threshold escolhido
$ciYaml = $ciYaml -replace '__THRESHOLD__', [string]$CoverageThreshold
Set-Content -Path $wfFile -Value $ciYaml -Encoding UTF8
Log "Wrote $wfFile"

# --- conteúdo do get-coverage.ps1 (v2)
$coverageScript = @'
<# Get-coverage.ps1 — baixa e abre o relatório do último CI bem-sucedido #>
[CmdletBinding()]
param(
  [string]$Workflow = 'CI',
  [string]$Branch   = 'main',
  [string]$Artifact = 'merged-coverage-report',
  [string]$OutDir   = '.\coverage-ci\merged',
  [switch]$Open,
  [string]$FallbackBranch = 'main',   # tenta este se não houver run no Branch
  [string]$RunId,                     # baixa de um run específico
  [switch]$Clean                      # limpa o OutDir antes de baixar
)

$ErrorActionPreference = 'Stop'

function Log([string]$msg) { Write-Host "[$(Get-Date -Format HH:mm:ss)] $msg" }
function Get-Json($cmd) {
  try {
    $raw = & gh api -H "Accept: application/vnd.github+json" $cmd
    if (-not $raw) { return $null }
    return $raw | ConvertFrom-Json
  } catch {
    throw "Falha ao executar: gh api $cmd`n$($_.Exception.Message)"
  }
}

function Find-LastSuccessRun([string]$workflowName, [string]$branch) {
  $runs = Get-Json "repos/:owner/:repo/actions/runs?branch=$branch&per_page=50"
  if (-not $runs) { return $null }
  $run = $runs.workflow_runs |
    Where-Object { $_.name -eq $workflowName -and $_.status -eq 'completed' -and $_.conclusion -eq 'success' } |
    Sort-Object -Property created_at -Descending |
    Select-Object -First 1
  return $run
}

try { & gh --version | Out-Null } catch { throw "GitHub CLI (gh) não encontrado no PATH." }
if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Execute no diretório do repositório git." }

$runMeta = $null
if ($PSBoundParameters.ContainsKey('RunId') -and $RunId) {
  Log "Usando RunId fornecido: $RunId"
  $runMeta = Get-Json "repos/:owner/:repo/actions/runs/$RunId"
  if (-not $runMeta) { throw "Não foi possível obter metadados do run $RunId." }
} else {
  Log "Procurando último run 'success' em '$Branch' para workflow '$Workflow'..."
  $runMeta = Find-LastSuccessRun -workflowName $Workflow -branch $Branch
  if (-not $runMeta -and $Branch -ne $FallbackBranch) {
    Log "Nenhum run 'success' em '$Branch'. Tentando fallback '$FallbackBranch'..."
    $runMeta = Find-LastSuccessRun -workflowName $Workflow -branch $FallbackBranch
  }
  if (-not $runMeta) { throw "Nenhum run 'success' encontrado para workflow '$Workflow'." }
}

$runId = $runMeta.id
Log "✓ Run: $($runMeta.name)  id=$runId  at=$($runMeta.created_at)  branch=$($runMeta.head_branch)"

if ($Clean -and (Test-Path $OutDir)) {
  Log "Limpando $OutDir ..."
  Remove-Item $OutDir -Recurse -Force
}
if (-not (Test-Path $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$arts = Get-Json "repos/:owner/:repo/actions/runs/$runId/artifacts?per_page=100"
$art  = $arts.artifacts | Where-Object { $_.name -eq $Artifact -and $_.expired -eq $false } | Select-Object -First 1
if (-not $art) {
  $disp = ($arts.artifacts | ForEach-Object { $_.name }) -join ', '
  throw "Artifact '$Artifact' não encontrado no run $runId. Disponíveis: $disp"
}

Log "Baixando artifact '$Artifact' para $OutDir ..."
& gh run download $runId -n $Artifact -D $OutDir
Log "↓ Artifact baixado."

$summaryFile = Get-ChildItem -Path $OutDir -Recurse -Filter 'coverage-summary.json' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($summaryFile) {
  Log "Lendo resumo: $($summaryFile.FullName)"
  $js = Get-Content $summaryFile.FullName -Raw | ConvertFrom-Json
  $t = $js.total
  "{0,-12} {1,8} {2,10} {3,10} {4,10}" -f 'Métrica','Pct(%)','Cobertos','Total','Miss'
  "{0,-12} {1,8:N1} {2,10} {3,10} {4,10}" -f 'Statements', $t.statements.pct, $t.statements.covered, $t.statements.total, ($t.statements.total - $t.statements.covered)
  "{0,-12} {1,8:N1} {2,10} {3,10} {4,10}" -f 'Branches',   $t.branches.pct,   $t.branches.covered,   $t.branches.total,   ($t.branches.total   - $t.branches.covered)
  "{0,-12} {1,8:N1} {2,10} {3,10} {4,10}" -f 'Functions',  $t.functions.pct,  $t.functions.covered,  $t.functions.total,  ($t.functions.total  - $t.functions.covered)
  "{0,-12} {1,8:N1} {2,10} {3,10} {4,10}" -f 'Lines',      $t.lines.pct,      $t.lines.covered,      $t.lines.total,      ($t.lines.total      - $t.lines.covered)
} else {
  Log "(coverage-summary.json não encontrado; vou apenas procurar index.html)"
}

if ($Open) {
  $index = Get-ChildItem -Path $OutDir -Recurse -Filter 'index.html' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($index) {
    Start-Process $index.FullName
    Log "🡕 Abrindo: $($index.FullName)"
  } else {
    Log "index.html não encontrado dentro de $OutDir."
  }
}

Log "Concluído."
'@

Set-Content -Path $getCov -Value $coverageScript -Encoding UTF8
Log "Wrote $getCov"

# desabilitar workflow 'api-ci' (mover para backup)
if ($DisableApiCi) {
  Log "Tentando desabilitar workflow 'api-ci (lint + typecheck + test)'..."
  $wfJson = & gh workflow list --json name,path,state | ConvertFrom-Json
  $api = $wfJson | Where-Object { $_.name -like 'api-ci*' }
  if ($api -and $api.path) {
    $src = $api.path
    $dst = Join-Path $backupDir ((Split-Path $src -Leaf) + ".disabled")
    if (Test-Path $src) {
      Move-Item $src $dst -Force
      Log "Movido: $src -> $dst"
    } else {
      Log "Aviso: caminho reportado pelo gh não existe localmente: $src"
    }
  } else {
    $cand = Get-ChildItem $wfDir -Filter "*api-ci*.yml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) {
      $dst = Join-Path $backupDir ($cand.Name + ".disabled")
      Move-Item $cand.FullName $dst -Force
      Log "Movido: $($cand.FullName) -> $dst"
    } else {
      Log "Workflow 'api-ci' não encontrado para desabilitar (ok)."
    }
  }
}

# git add/commit/push
if ($Push) {
  git add $wfFile $getCov 2>$null | Out-Null
  if ($DisableApiCi) { git add $wfDir 2>$null | Out-Null }
  $changes = git status --porcelain
  if ([string]::IsNullOrWhiteSpace($changes)) {
    Log "Sem alterações para commit."
  } else {
    & git commit -m $CommitMessage
    & git push
  }
}

# disparar workflow e aguardar
$lastRunId = $null
if ($Run) {
  Log "Disparando workflow: $wfFile"
  & gh workflow run $wfFile | Out-Null
  Start-Sleep -Seconds 3
  $lastRunId = (gh run list -w $wfFile -L 1 --json databaseId -q '.[0].databaseId')
  if (-not $lastRunId) { throw "Não consegui obter o run id." }
  Log "Aguardando run $lastRunId finalizar..."
  & gh run watch $lastRunId --exit-status
}

# baixar coverage e abrir
if ($Run -and $Open) {
  Log "Baixando coverage do run $lastRunId..."
  & $getCov -RunId $lastRunId -Open -Clean
}

Log "Rebuild-CI concluído."
'@ | Set-Content -Path .\tools\rebuild-ci.ps1 -Encoding UTF8
