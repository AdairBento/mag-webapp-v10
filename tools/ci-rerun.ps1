param(
  [string]$Message = "ci: re-run",
  [switch]$NoPush,      # use -NoPush para só criar o commit vazio sem enviar
  [switch]$NoVerify     # use -NoVerify para pular hooks (pre-commit / pre-push)
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

# 3) Descobrir branch atual
$branch = (& $gitExe rev-parse --abbrev-ref HEAD).Trim()

Write-Host "`n==> Commit vazio para re-rodar CI na branch '$branch'" -ForegroundColor Cyan

# 4) Commit vazio
$commitArgs = @('commit', '--allow-empty', '-m', $Message)
if ($NoVerify) { $commitArgs += '--no-verify' }
& $gitExe @commitArgs

# 5) Push (a menos que peça pra não enviar)
if (-not $NoPush) {
  Write-Host "Enviando para origin/$branch..." -ForegroundColor Cyan
  $pushArgs = @('push', '-u', 'origin', $branch)
  if ($NoVerify) { $pushArgs += '--no-verify' }  # opcional: pula pre-push
  & $gitExe @pushArgs
} else {
  Write-Host "Push desabilitado (--NoPush). Só criei o commit local." -ForegroundColor Yellow
}

Write-Host "OK: CI acionado com mensagem '$Message'." -ForegroundColor Green
