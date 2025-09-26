<# =========================[ MAG Audit Script ]=========================
Gera inventário de arquivos, roda ESLint (raiz e pacotes), e cria relatório MD.
#>

param(
  [string]$ProjectRoot = (Resolve-Path '.').Path,
  [string]$OutputDir   = ".\audit-reports"
)

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'PlainText'

function Resolve-NodePath {
  $c = Get-Command node -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $c = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $cands = @()
  if ($env:NVM_SYMLINK) { $cands += (Join-Path $env:NVM_SYMLINK 'node.exe') }
  if ($env:NVM_HOME)    { $cands += (Join-Path $env:NVM_HOME 'node.exe'); $cands += (Get-ChildItem -Path (Join-Path $env:NVM_HOME 'v*') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'node.exe' }) }
  $cands += "$env:ProgramFiles\nodejs\node.exe", "$env:ProgramFiles(x86)\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe", "C:\Program Files\nodejs\node.exe"
  foreach ($p in $cands) { if ($p -and (Test-Path $p)) { return $p } }
  throw "Node.js não encontrado no PATH nem nos locais comuns. Abra um terminal onde 'node -v' funcione ou instale o Node."
}

function Find-PackageDirs {
  param([string]$root)
  $set = [System.Collections.Generic.HashSet[string]]::new()
  $add = { param($p) if ($p -and (Test-Path (Join-Path $p 'package.json'))) { [void]$set.Add((Resolve-Path $p).Path) } }
  & $add $root; & $add (Join-Path $root 'api'); & $add (Join-Path $root 'web')
  & $add (Join-Path $root 'apps\api'); & $add (Join-Path $root 'apps\web')
  Get-ChildItem -Path $root -Recurse -Depth 3 -Filter package.json -ErrorAction SilentlyContinue | ForEach-Object { [void]$set.Add((Resolve-Path $_.Directory.FullName).Path) }
  return @($set)
}

function Run-ESLint {
  param([Parameter(Mandatory)][string]$dir,[Parameter(Mandatory)][string]$logPath)
  if (-not (Test-Path (Join-Path $dir 'package.json'))) { return $false }
  $logDir = (Split-Path $logPath); if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
  Push-Location $dir
  try {
    $node = Resolve-NodePath
    $eslintJs = Join-Path $dir 'node_modules\eslint\bin\eslint.js'
    if (Test-Path $eslintJs) {
      & $node $eslintJs . --ext .ts,.tsx,.js,.jsx -f json -o "$logPath" --no-error-on-unmatched-pattern | Out-Null
      return $true
    }
    # fallback 1: binários locais .cmd/.ps1 (se Node já estiver no PATH desta sessão)
    $eslintCmd = Join-Path $dir 'node_modules\.bin\eslint.cmd'
    $eslintPs1 = Join-Path $dir 'node_modules\.bin\eslint.ps1'
    if (Test-Path $eslintCmd) { & $eslintCmd . --ext .ts,.tsx,.js,.jsx -f json -o "$logPath" --no-error-on-unmatched-pattern | Out-Null; return $true }
    if (Test-Path $eslintPs1) { & $eslintPs1 . --ext .ts,.tsx,.js,.jsx -f json -o "$logPath" --no-error-on-unmatched-pattern | Out-Null; return $true }
    # fallback 2: npx (se disponível na sessão)
    $npx = (Get-Command npx -ErrorAction SilentlyContinue)?.Source
    if ($npx) { & $npx eslint . --ext .ts,.tsx,.js,.jsx -f json -o "$logPath" --no-error-on-unmatched-pattern | Out-Null; return $true }
    Write-Host "ESLint não encontrado em '$dir'. Instale com: npm i -D eslint" -ForegroundColor Yellow
    return $false
  } catch {
    Write-Host "Falha ao rodar ESLint em '$dir': $($_.Exception.Message)" -ForegroundColor Red
    return $false
  } finally { Pop-Location }
}

function Merge-ESLintJson {
  param([string[]]$files,[string]$outPath)
  $all=@()
  foreach($f in $files){
    if(Test-Path $f){
      try{ $json=Get-Content $f -Raw|ConvertFrom-Json; if($json -is [System.Collections.IEnumerable]){ $all+=$json } }
      catch{ Write-Host "Erro ao ler JSON: $f ($($_.Exception.Message))" -ForegroundColor Red }
    }
  }
  ($all|ConvertTo-Json -Depth 10)|Set-Content -Path $outPath -Encoding UTF8
}

function Generate-ESLintSummary {
  param([Parameter(Mandatory)][string]$eslintJsonPath)
  if(-not(Test-Path $eslintJsonPath)){ return @("*(Sem resultados de ESLint)*") }
  $json=Get-Content $eslintJsonPath -Raw|ConvertFrom-Json
  if(-not $json){ return @("*(ESLint retornou vazio)*") }
  $lines=@(); $lines+="| Arquivo | Erros | Avisos |"; $lines+="|--------|------:|------:|"
  $totalErrs=0; $totalWarns=0
  foreach($fileReport in $json){
    $errs=($fileReport.messages|Where-Object{$_.severity-eq 2}).Count
    $warns=($fileReport.messages|Where-Object{$_.severity-eq 1}).Count
    $name=[System.IO.Path]::GetFileName($fileReport.filePath)
    $lines+="| $name | $errs | $warns |"
    $totalErrs+=$errs; $totalWarns+=$warns
  }
  $lines+=""; $lines+="**Totais:** $totalErrs erros, $totalWarns avisos."; return $lines
}

function Get-FileInventory {
  param([Parameter(Mandatory)][string]$path)
  $base=(Resolve-Path $path).Path
  Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue|ForEach-Object{
    $full=(Resolve-Path $_.FullName).Path
    [pscustomobject]@{ Path=$full.Replace("$base\",""); Size=$_.Length; LastWrite=$_.LastWriteTime; MD5=(Get-FileHash -Path $full -Algorithm MD5).Hash }
  }
}

$ProjectRoot=(Resolve-Path $ProjectRoot).Path
if(-not(Test-Path $OutputDir)){ New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$ts=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$invPath=Join-Path $OutputDir "file_inventory_$ts.csv"
$eslintJson=Join-Path $OutputDir "eslint_report_$ts.json"
$mdReport=Join-Path $OutputDir "full_audit_report_$ts.md"

Write-Host "Gerando inventário..." -ForegroundColor Cyan
$inventory=Get-FileInventory -path $ProjectRoot
$inventory|Export-Csv -NoTypeInformation -Encoding UTF8 -Path $invPath

Write-Host "Executando ESLint..." -ForegroundColor Cyan
$pkgDirs=Find-PackageDirs -root $ProjectRoot|Sort-Object -Unique
$partials=@()
foreach($dir in $pkgDirs){
  $name=Split-Path $dir -Leaf
  $partial=Join-Path $OutputDir "eslint_${name}_$ts.json"
  if(Run-ESLint -dir $dir -logPath $partial){ $partials+=$partial }
}

Merge-ESLintJson -files $partials -outPath $eslintJson
$eslintSummary=Generate-ESLintSummary -eslintJsonPath $eslintJson

$report=@()
$report+="# Auditoria de Código - Relatório Completo"
$report+=""; $report+="Data da geração: $ts"; $report+=""
$report+="## Inventário de Arquivos"; $report+=""
$report+="- Arquivo CSV: `$(Split-Path $invPath -Leaf)`"; $report+=""
$report+="## Sumário ESLint por arquivo"; $report+=""
$report+=$eslintSummary; $report+=""

$report|Set-Content -Path $mdReport -Encoding UTF8
Write-Host ""; Write-Host "✅ Inventário : $invPath" -ForegroundColor Green
Write-Host "✅ ESLint JSON: $eslintJson" -ForegroundColor Green
Write-Host "✅ Relatório  : $mdReport" -ForegroundColor Green; Write-Host ""
