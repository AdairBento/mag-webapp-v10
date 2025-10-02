param(
  [string]$Name,                      # opcional: nome da tag
  [string]$Message = "checkpoint",    # mensagem da tag anotada
  [switch]$NoPush                     # -NoPush para não enviar ao remoto
)

$ErrorActionPreference = "Stop"

# 1) Garantir git na sessão (sem alias confuso)
if (Test-Path Alias:git) { Remove-Item Alias:git -Force }
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue)?.Source
if (-not $gitExe) {
  $cands = @(
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files (x86)\Git\cmd\git.exe",
    "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
  ) | Where-Object { Test-Path $_ }
  if ($cands.Count) { $gitExe = $cands[0] } else { throw "git.exe não encontrado" }
}

# 2) Ir para a raiz do repo (funciona rodando o .ps1 ou colando no console)
$repoRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (& $gitExe rev-parse --show-toplevel).Trim() }
Set-Location $repoRoot

# 3) Nome da tag (timestamp) se não informado
if (-not $Name) { $Name = "checkpoint-" + (Get-Date -Format "yyyyMMdd-HHmm") }

# 4) Contexto na tela
$branch = (& $gitExe rev-parse --abbrev-ref HEAD).Trim()
$last   = & $gitExe log -1 --pretty=format:"%h %s (%ci)"
Write-Host "`n==> Criando tag '$Name' em $branch" -ForegroundColor Cyan
Write-Host "Último commit: $last"

# 5) Criar tag anotada (idempotente simples)
if (& $gitExe tag --list $Name) { & $gitExe tag -d $Name | Out-Null }
& $gitExe tag -a $Name -m $Message

# 6) Push opcional
if (-not $NoPush) {
  Write-Host "Enviando tag para origin..." -ForegroundColor Cyan
  & $gitExe push origin $Name
} else {
  Write-Host "Push desabilitado (--NoPush). Tag criada apenas localmente." -ForegroundColor Yellow
}

Write-Host "OK: tag '$Name' pronta." -ForegroundColor Green
