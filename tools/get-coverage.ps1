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
