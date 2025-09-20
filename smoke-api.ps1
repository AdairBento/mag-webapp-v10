param(
  [string]$Base = "http://127.0.0.1:3001",
  [string]$Email = "cliente.demo@mag.dev",
  [string]$Password = "mag123456",
  [string]$ApiDir = "api",
  [switch]$StartServer
)

$ErrorActionPreference='Stop'

if ($StartServer) {
  # libera porta e sobe server em outra janela do PowerShell
  $tcp = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
  if ($tcp) { try { Stop-Process -Id $tcp.OwningProcess -Force } catch {} }
  Start-Process -WindowStyle Minimized pwsh -ArgumentList `
    '-NoExit','-ExecutionPolicy Bypass',"-Command","cd `"$ApiDir`"; `$env:NODE_ENV='development'; npm run dev"
}

# espera /healthz até 20s
$deadline=(Get-Date).AddSeconds(20)
do {
  try { $h = Invoke-RestMethod "$Base/healthz"; $ok=$h.ok } catch { $ok=$false; Start-Sleep 1 }
} while(-not $ok -and (Get-Date) -lt $deadline)

if (-not $ok) { throw "API não respondeu /healthz a tempo" }
Write-Host "✓ /healthz OK" -ForegroundColor Green

# lista rotas
$routes = Invoke-RestMethod "$Base/debug/routes"
Write-Host "Rotas:" -ForegroundColor Cyan
$routes | ForEach-Object { "{0,-6} {1}" -f $_.methods, $_.path } | Write-Host

# login
$login = @{ email=$Email; password=$Password } | ConvertTo-Json
$resp  = Invoke-RestMethod -Uri "$Base/auth/login" -Method POST -Body $login -ContentType "application/json"
$token = $resp.token
if (-not $token) { throw "Login falhou" }
Write-Host "✓ login OK" -ForegroundColor Green

# /me
$me = Invoke-RestMethod "$Base/me" -Headers @{ Authorization = "Bearer $token" }
Write-Host "/me ->" -ForegroundColor Cyan
$me | ConvertTo-Json -Depth 5 | Write-Host

# /api/users
$users = Invoke-RestMethod "$Base/api/users" -Headers @{ Authorization = "Bearer $token" }
Write-Host "/api/users ->" -ForegroundColor Cyan
$users | ConvertTo-Json | Write-Host

Write-Host "✅ smoke passou." -ForegroundColor Green
