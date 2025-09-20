param(
  [string]$SchemaPath   = "api\prisma\schema.prisma",
  [switch]$Push,
  [switch]$Generate,
  [string]$PrismaVersion = "",
  [int]$Port = 3001,
  [string]$DotenvPath = ""   # opcional: se quiser forçar um .env específico
)

$ErrorActionPreference = 'Stop'
Write-Host "🧹 Fix Prisma iniciado..." -ForegroundColor Cyan

function Load-DotEnv([string]$path) {
  if (!(Test-Path $path)) { return }
  Write-Host "📄 Carregando .env: $path" -ForegroundColor DarkGray
  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    if ($line -match '^\s*([^=]+?)\s*=\s*(.*)\s*$') {
      $k = $matches[1]; $v = $matches[2]
      # remove aspas e converte \n
      $v = $v -replace '^"(.*)"$','$1' -replace "^'(.*)'$",'$1'
      $v = $v -replace '\\n', "`n"
      [Environment]::SetEnvironmentVariable($k, $v, "Process")
      Set-Item -Path Env:$k -Value $v | Out-Null
    }
  }
}

# 0) caminhos do schema / .env
$schemaFull = Resolve-Path $SchemaPath
$schemaDir  = Split-Path -Parent $schemaFull
if (-not $DotenvPath) { $DotenvPath = Join-Path $schemaDir ".env" }

# 1) derruba node e a porta
try { Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force } catch {}
try {
  $tcp = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($tcp) { Stop-Process -Id $tcp.OwningProcess -Force }
} catch {}
Start-Sleep -Milliseconds 300

# 2) limpa engine gerado
$enginePath = Join-Path (Get-Location).Path "node_modules\.prisma\client"
if (Test-Path $enginePath) {
  Remove-Item -Recurse -Force $enginePath -ErrorAction SilentlyContinue
  Write-Host "🗑  Removido $enginePath" -ForegroundColor DarkGray
}

# 3) garante paridade (opcional)
if ($PrismaVersion) {
  Write-Host "📦 Ajustando versões prisma/@prisma/client -> $PrismaVersion"
  npm i -D ("prisma@{0}" -f $PrismaVersion)
  npm i    ("@prisma/client@{0}" -f $PrismaVersion)
}

# 4) carrega .env do schema e executa os comandos a partir do diretório do schema
Load-DotEnv $DotenvPath

if (-not $Push -and -not $Generate) { $Generate = $true } # default
Push-Location $schemaDir
try {
  if ($Generate) {
    Write-Host "⚙  npx prisma generate --schema=$schemaFull"
    npx prisma generate --schema=$schemaFull
  }
  if ($Push) {
    Write-Host "⚙  npx prisma db push --schema=$schemaFull"
    npx prisma db push --schema=$schemaFull
  }
} finally {
  Pop-Location
}

Write-Host "✅ Fix Prisma concluído." -ForegroundColor Green
