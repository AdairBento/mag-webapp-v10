$ErrorActionPreference = "Stop"
if (Test-Path Alias:git) { Remove-Item Alias:git -Force }
$gitDir = "C:\Program Files\Git\cmd"
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { if (Test-Path $gitDir) { $env:Path += ";$gitDir" } }

$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$last   = (git log -1 --pretty=format:"%h %s (%ci)")

Write-Host "`n==== CHECKPOINT @ $ts ====" -ForegroundColor Cyan
Write-Host "Branch: $branch"
Write-Host "Último commit: $last"
Write-Host "tsconfig.test.json: rootDir='.'; include .ts/.d.ts; types ['node','vitest']"
Write-Host "tests/types/express.d.ts: Express.Request.user?: { id: string }"

# Dry-runs úteis
Write-Host "`nTypecheck (app+tests)..." -ForegroundColor DarkCyan
npm --workspace @mag/api run typecheck

Write-Host "`nVitest (resumo)..." -ForegroundColor DarkCyan
npm --workspace @mag/api exec -- vitest run

Write-Host "`nArquivos pendentes:" -ForegroundColor DarkCyan
git status --short
Write-Host "===========================`n" -ForegroundColor Cyan


