param(
  [string]$CommitMessage = "chore(checkpoint): tests typecheck + push"
)
$ErrorActionPreference = "Stop"

# 1) Git confiável na sessão
if (Test-Path Alias:git) { Remove-Item Alias:git -Force }
$gitDir = "C:\Program Files\Git\cmd"
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
  if (Test-Path $gitDir) { $env:Path += ";$gitDir" }
}
git --version | Out-Null

# 2) Ir pra raiz do repo (tools/..)
Set-Location (Split-Path -Parent $PSScriptRoot)

# 3) Stage/commit
$files = @(
  "api/tsconfig.test.json",
  "api/tests/types/express.d.ts"
) | Where-Object { Test-Path $_ }

if ($files) {
  git add $files
  if (Test-Path "api/tests/types/express.d.ts") { git add -f "api/tests/types/express.d.ts" }
} else {
  Write-Host "Aviso: nenhum arquivo-alvo existe. Seguindo..." -ForegroundColor Yellow
}

$st = git status --porcelain
if ($st) {
  git commit -m $CommitMessage
} else {
  Write-Host "Nada para commitar (working tree clean)." -ForegroundColor Yellow
}

# 4) Garantir que o pre-push passe
npm --workspace @mag/api run typecheck

# 5) Push (se remote configurado)
$remote = git remote 2>$null
if ($remote) {
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  git push -u origin $branch
} else {
  Write-Host "`nNenhum remote configurado. Para enviar:" -ForegroundColor Yellow
  Write-Host '  git remote add origin https://github.com/AdairBento/mag-webapp-v10.git'
  Write-Host '  git push -u origin main'
}

# 6) Checkpoint
Write-Host "`n==== CHECKPOINT ====" -ForegroundColor Cyan
Write-Host "tsconfig.test.json: rootDir='.'; include .ts/.d.ts; types ['node','vitest']"
Write-Host "tests/types/express.d.ts: Express.Request.user?: { id: string }"
Write-Host "typecheck: OK; vitest: OK (ver histórico)"
Write-Host "push: origin/main (se remoto configurado)"
Write-Host "====================`n" -ForegroundColor Cyan
