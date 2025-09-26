# tools\build_and_report.ps1
# Executa npm ci + typecheck na pasta api e gera relatório em artifact\audit_report\audit-report.html

$ErrorActionPreference = 'Stop'

# --- 1) Descobrir raiz do repo ---
function Get-RepoRoot {
  try {
    $r = (& git rev-parse --show-toplevel) 2>$null
    if ($r) { return $r }
  } catch {}
  if ($MyInvocation.MyCommand.Path) { return (Split-Path -Parent $MyInvocation.MyCommand.Path) }
  return (Resolve-Path '.').Path
}
$repoRoot = Get-RepoRoot
$apiDir   = Join-Path $repoRoot 'api'
if (-not (Test-Path $apiDir)) { throw "Pasta 'api' não encontrada: $apiDir" }

# --- 2) NVM/NODE no PATH ---
$NVM_HOME = [Environment]::GetEnvironmentVariable('NVM_HOME','Machine')
if (-not $NVM_HOME) { $NVM_HOME = [Environment]::GetEnvironmentVariable('NVM_HOME','User') }
if (-not $NVM_HOME) {
  $NVM_HOME = @("C:\Users\$env:USERNAME\AppData\Local\nvm","C:\Program Files\nvm","C:\Users\$env:USERNAME\AppData\Roaming\nvm") |
              Where-Object { Test-Path $_ } | Select-Object -First 1
}
$NVM_SYMLINK = [Environment]::GetEnvironmentVariable('NVM_SYMLINK','Machine')
if (-not $NVM_SYMLINK) { $NVM_SYMLINK = [Environment]::GetEnvironmentVariable('NVM_SYMLINK','User') }
if (-not $NVM_SYMLINK) {
  $NVM_SYMLINK = @("C:\nvm4w\nodejs","C:\Program Files\nodejs") |
                 Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($NVM_HOME)    { $env:PATH = "$NVM_HOME;$env:PATH" }
if ($NVM_SYMLINK) { $env:PATH = "$NVM_SYMLINK;$env:PATH" }

# --- 3) Resolver npm ---
function Resolve-Npm {
  param([string]$preferDir)
  $cands = @()
  if ($preferDir) {
    $cands += (Join-Path $preferDir 'npm.cmd'), (Join-Path $preferDir 'npm.exe')
  }
  $gc = Get-Command npm -ErrorAction SilentlyContinue
  if ($gc) { $cands += $gc.Source }
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
  throw "npm não encontrado no PATH."
}
$NPM = Resolve-Npm -preferDir $NVM_SYMLINK

# --- 4) Limpar aliases antigos ---
Remove-Item Function:npm,Function:npx,Alias:npm,Alias:npx -ErrorAction SilentlyContinue
if ($NVM_SYMLINK -and (Test-Path (Join-Path $NVM_SYMLINK 'npm.cmd'))) {
  Set-Alias npm (Join-Path $NVM_SYMLINK 'npm.cmd')
}
if ($NVM_SYMLINK -and (Test-Path (Join-Path $NVM_SYMLINK 'npx.cmd'))) {
  Set-Alias npx (Join-Path $NVM_SYMLINK 'npx.cmd')
}

# --- 5) npm ci + typecheck ---
& $NPM --prefix $apiDir ci
& $NPM --prefix $apiDir run -s typecheck

# --- 6) Relatório ---
$relScript  = Join-Path $repoRoot 'gera_relatorio_local.ps1'
$artifact   = Join-Path $repoRoot 'artifact\audit_report'
$reportPath = Join-Path $artifact 'audit-report.html'
New-Item -ItemType Directory -Force -Path $artifact | Out-Null

if (Test-Path $relScript) {
  powershell -NoProfile -ExecutionPolicy Bypass -File $relScript
}

if (-not (Test-Path $reportPath)) {
  $generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $nodeVer = (& node -v) 2>$null
  $npmVer  = (& $NPM -v) 2>$null
@"
<!doctype html>
<html><head><meta charset="utf-8"><title>AUDIT REPORT</title></head>
<body>
<h1>Audit Report (fallback)</h1>
<p><b>Gerado em:</b> $generatedAt</p>
<p><b>Repo root:</b> $repoRoot</p>
<p><b>API dir:</b> $apiDir</p>
<p><b>Node:</b> $nodeVer | <b>NPM:</b> $npmVer</p>
<ul>
  <li>npm ci concluído</li>
  <li>npm run typecheck concluído</li>
</ul>
</body></html>
"@ | Set-Content -Encoding UTF8 -Path $reportPath
}

Write-Host "OK: $reportPath"
start $reportPath
