param(
  [string]$Name,                                 # opcional: nome da tag
  [string]$Message = "checkpoint",               # mensagem anotada da tag
  [switch]$NoPush                                # use -NoPush para não enviar ao remoto
)

$ErrorActionPreference = "Stop"

# 1) Garantir git.exe (sem alias confuso)
if (Test-Path Alias:git) { Remove-Item Alias:git -Force }
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue)?.Source
if (-not $gitExe) {
  $cands = @(
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files (x86)\Git\cmd\git.exe",
    "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
  ) | Where-Object { Test-Path $_ }
  if ($cands.Count -gt 0) { $gitExe = $cands[0] }
}
if (-not $gitExe) { throw "git.exe não encontrado. Instale o Git ou informe o caminho." }

# 2) Descobrir raiz do repositório
$repoRoot = $null
if ($PSScriptRoot) { $repoRoot = Split-Path -Parent $PSScriptRoot }
if (-not $repoRoot) {
  try { $repoRoot = (& $gitExe rev-parse --show-toplevel) 2>$null } catch {}
}
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

Set-Location $repoRoot

# 3) Nome da tag
if (-not $Name) { $Name = "checkpoint-" + (Get-Date -Format "yyyyMMdd-HHmm") }

# 4) Evitar colisão de tag
$exists = (& $gitExe tag --list $Name)
if ($exists) { throw "A tag '$Name' já existe. Use -Name para outro nome." }

# 5) Contexto e criação da tag
$branch = (& $gitExe rev-parse --abbrev-ref HEAD).Trim()
$last   = & $gitExe log -1 --pretty=format:"%h %s (%ci)"

Write-Host ""
Write-Host "==> Criando tag '$Name' em $branch" -ForegroundColor Cyan
Write-Host "Último commit: $last"

& $gitExe tag -a $Name -m $Message

# 6) Push (a menos que -NoPush)
if (-not $NoPush) {
  Write-Host "Enviando tag para origin..." -ForegroundColor Cyan
  & $gitExe push origin $Name
  Write-Host "OK: tag '$Name' enviada." -ForegroundColor Green
} else {
  Write-Host "OK: tag '$Name' criada localmente (sem push)." -ForegroundColor Yellow
}
