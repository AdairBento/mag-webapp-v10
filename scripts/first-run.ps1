[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# 1) Postgres
docker compose -f (Join-Path $root 'docker-compose.yml') up -d postgres

# 2) Espera ficar healthy
$deadline = (Get-Date).AddSeconds(80)
do {
  try { $h = docker inspect -f '{{.State.Health.Status}}' 'magv10-postgres' 2>$null } catch { $h = '' }
  if ($h -eq 'healthy') { break }
  Start-Sleep 2
} while ((Get-Date) -lt $deadline)
if ($h -ne 'healthy') { throw 'Postgres não ficou saudável a tempo.' }

# 3) Prisma + deps API
$api = Join-Path $root 'api'
if (Test-Path (Join-Path $api '.env')) {
  Push-Location $api
  try {
    if (!(Test-Path 'node_modules')) { npm i }
    npx prisma db push --schema=prisma/schema.prisma
    npx prisma generate --schema=prisma/schema.prisma
  } finally { Pop-Location }
}

# 4) Frontend .env + deps
$front = Join-Path $root 'frontend'
if (Test-Path $front) {
  $frontEnv = Join-Path $front '.env'
  if (-not (Test-Path $frontEnv)) {
    "VITE_API_BASE=http://127.0.0.1:3001
VITE_TENANT=dev" | Set-Content -Encoding UTF8 -Path $frontEnv
  }
  if (!(Test-Path (Join-Path $front 'node_modules'))) {
    Push-Location $front; try { npm i } finally { Pop-Location }
  }
}

# 5) Start API e Front usando -WorkingDirectory (sem Set-Location)
if (Test-Path $api)   { Start-Process -FilePath 'npm' -ArgumentList 'run','dev' -WorkingDirectory $api }
if (Test-Path $front) { Start-Process -FilePath 'npm' -ArgumentList 'run','dev' -WorkingDirectory $front }

Start-Sleep 2
Start-Process 'http://127.0.0.1:3000'
