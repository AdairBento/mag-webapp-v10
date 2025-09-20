[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
docker compose -f (Join-Path $root 'docker-compose.yml') up -d postgres
$api  = Join-Path $root 'api'
$front= Join-Path $root 'frontend'
if (Test-Path $api)   { Start-Process -FilePath 'npm' -ArgumentList 'run','dev' -WorkingDirectory $api }
if (Test-Path $front) { Start-Process -FilePath 'npm' -ArgumentList 'run','dev' -WorkingDirectory $front }
Start-Process 'http://127.0.0.1:3000'
