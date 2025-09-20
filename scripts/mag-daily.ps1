[CmdletBinding()]
param([string]$BackupDir="$env:USERPROFILE\Backups\MAGv10")
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dump = Join-Path $BackupDir "magv10_$timestamp.sql"
docker exec 'magv10-postgres' pg_dump -U maguser -d magv10 > $dump
Write-Host "Backup salvo em $dump" -ForegroundColor Green
