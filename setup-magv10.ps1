# --- setup-magv10.ps1 ---
[CmdletBinding()]
param(
    [string]$Repo        = "C:\Users\adair\PycharmProjects\mag-webapp-v10",
    [string]$ApiPath     = "api",
    [string]$Base        = "http://127.0.0.1:3000",
    [string]$TenantId    = "dev",
    [int]$Port           = 3000,
    [string]$StartCmd    = "npm run dev",
    [string]$SeedEmail   = "cliente.demo@mag.dev",
    [string]$SeedPassword = "123456"
)

Write-Host "Executando setup do MAG v10..."

# Exemplo de ação do setup:
$envFile = Join-Path $Repo "$ApiPath\.env"
if (-not (Test-Path $envFile)) {
    @"
DATABASE_URL=postgresql://maguser:magpass123@localhost:5434/magv10?schema=public
PORT=$Port
SEED_EMAIL=$SeedEmail
SEED_PASSWORD=$SeedPassword
"@ | Set-Content -Encoding UTF8 $envFile
    Write-Host ".env criado em $envFile"
} else {
    Write-Host ".env já existe em $envFile"
}
