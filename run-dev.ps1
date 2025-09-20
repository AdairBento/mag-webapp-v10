param(
  [string]$Port = "3001",
  [switch]$NoDocker
)

$ErrorActionPreference = "Stop"
$root = "C:\Users\adair\PycharmProjects\mag-webapp-v10"
$api  = Join-Path $root "api"

function Ensure-Paths {
  $dockerPaths = @("C:\Program Files\Docker\Docker\resources\bin","C:\ProgramData\DockerDesktop\version-bin")
  foreach ($p in $dockerPaths) { if (Test-Path $p) { $env:Path = "$env:Path;$p" } }
  $env:Path += ';C:\Program Files\nodejs'
}

function Wait-Docker {
  $app = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  if (Test-Path $app) { Start-Process $app | Out-Null }
  $deadline = (Get-Date).AddMinutes(2)
  while ((Get-Date) -lt $deadline) {
    $v = docker version 2>$null
    if ($LASTEXITCODE -eq 0 -and $v -match 'Server') { return }
    Start-Sleep -Seconds 3
  }
  throw "Docker daemon não respondeu."
}

function Start-Compose {
  Push-Location $root
  docker compose up -d
  Pop-Location
  # wait healthy
  $deadline = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $deadline) {
    $s = docker inspect -f '{{.State.Health.Status}}' magv10-postgres 2>$null
    if ($s -eq 'healthy') { return }
    Start-Sleep -Seconds 2
  }
}

function Prisma-Generate-With-Retry {
  # matar processos que possam estar usando o engine
  Get-Process node, tsx -ErrorAction SilentlyContinue | Stop-Process -Force

  # limpar engine travado na RAIZ (monorepo)
  $engineDir = Join-Path $root "node_modules\.prisma\client"
  $engine    = Join-Path $engineDir "query_engine-windows.dll.node"
  Remove-Item $engine -Force -ErrorAction SilentlyContinue
  Get-ChildItem $engineDir -Filter "query_engine-windows.dll.node.tmp*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

  Push-Location $api
  $env:DATABASE_URL = 'postgresql://maguser:magpass123@localhost:5434/magv10?schema=public'

  $attempts = 0
  do {
    $attempts++
    try {
      npx prisma db push --schema=prisma/schema.prisma
      npx prisma generate
      Write-Host "[OK] Prisma generate concluído (tentativa $attempts)" -ForegroundColor Green
      Pop-Location
      return
    } catch {
      Write-Host "[WARN] Prisma generate falhou (tentativa $attempts). Detalhe: $($_.Exception.Message)" -ForegroundColor Yellow
      if ($attempts -ge 3) {
        Pop-Location
        throw "Prisma generate falhou após 3 tentativas."
      }
      Start-Sleep -Seconds 3
      # tenta limpar de novo
      Remove-Item $engine -Force -ErrorAction SilentlyContinue
      Get-Process node, tsx -ErrorAction SilentlyContinue | Stop-Process -Force
    }
  } while ($true)
}

function Start-Api {
  if (-not (Test-Path $api)) { throw "API não encontrada em $api" }
  Push-Location $api
  if (Test-Path .\package-lock.json) { npm ci } else { npm install }
  $env:PORT = $Port
  Start-Process powershell -ArgumentList "-NoExit","-Command","Set-Location '$api'; `$env:PORT='$Port'; npm run dev"
  Pop-Location
  Write-Host "API em http://localhost:$Port" -ForegroundColor Green
  Write-Host "Swagger: http://localhost:$Port/api-docs" -ForegroundColor Green
}

Ensure-Paths
if (-not $NoDocker) { Wait-Docker; Start-Compose }
Prisma-Generate-With-Retry
Start-Api
