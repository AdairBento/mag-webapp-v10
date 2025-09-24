param(
    [string]$ProjectPath = ".",
    [switch]$AutoCommit,
    [switch]$GenerateReport,
    [switch]$ShowDetails,
    # Opcional: comando de start (se não informado, tenta detectar "start"/"dev" no package.json)
    [string]$AppStart = "",
    # Opcional: URL de health (se vazio, tenta PORT -> http://127.0.0.1:3000/healthz)
    [string]$HealthUrl = "",
    # Tentativas/timeout do healthcheck
    [int]$HealthRetries = 30,
    [int]$HealthTimeoutSec = 2
)

# =========================
# Fail fast p/ comandos nativos
# =========================
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# =========================
# Cores
# =========================
$Colors = @{
    Success = "Green"; Warning = "Yellow"; Error = "Red"
    Info = "Cyan"; Task = "Magenta"; Done = "DarkGreen"
}

# =========================
# Tarefas (inclui extras + checks Postgres/App)
# =========================
$Tasks = @(
    @{ Name = "Verificar estrutura";                      Key = "structure";  Done = $false },
    @{ Name = "Verificar dependências";                   Key = "deps";       Done = $false },
    @{ Name = "Configurar ESLint";                        Key = "config";     Done = $false },
    @{ Name = "Executar TypeCheck";                       Key = "typecheck";  Done = $false },
    @{ Name = "Executar Lint";                            Key = "lint";       Done = $false },
    @{ Name = "Build (se existir script)";                Key = "build";      Done = $false },
    @{ Name = "Saúde do Postgres (pg_isready/docker)";    Key = "pg";         Done = $false },
    @{ Name = "Healthcheck (subir app antes dos testes)"; Key = "prehc";      Done = $false },
    @{ Name = "Executar Testes (real DB)";                Key = "tests";      Done = $false },
    @{ Name = "Healthcheck (após testes)";                Key = "posthc";     Done = $false },
    @{ Name = "Prisma migrate status";                    Key = "migrate";    Done = $false },
    @{ Name = "npm audit (moderate+)";                    Key = "audit";      Done = $false },
    @{ Name = "Verificar diffs pendentes";                Key = "diff";       Done = $false },
    @{ Name = "CI (último run via gh)";                   Key = "ci";         Done = $false },
    @{ Name = "Commit automático";                        Key = "commit";     Done = $false }
)

# =========================
# Paths normalizados
# =========================
$ProjectPath = (Resolve-Path $ProjectPath).Path
$ApiPath     = Join-Path $ProjectPath "api"

$LogFile  = Join-Path $ProjectPath "audit.log"
$JsonFile = Join-Path $ProjectPath "audit-result.json"
$HtmlFile = Join-Path $ProjectPath "audit-report.html"

# Zera log a cada execução
"" | Set-Content $LogFile -Encoding UTF8

# =========================
# Helpers gerais
# =========================
function Log($msg) {
    Add-Content $LogFile "$((Get-Date).ToString("s")) - $msg"
}

function In-Api([ScriptBlock]$ScriptBlock) {
    Push-Location $ApiPath
    try   { & $ScriptBlock }
    finally { Pop-Location }
}

function Execute($Name, $Key, [ScriptBlock]$Script) {
    Write-Host "🔄 $Name..." -ForegroundColor $Colors.Task
    try {
        $null = & $Script
        $ok = $LASTEXITCODE -eq 0
        if ($ok) {
            Write-Host "✅ $Name" -ForegroundColor $Colors.Success
            ($Tasks | Where-Object { $_.Key -eq $Key }).Done = $true
            Log "$Name - OK"
        } else {
            Write-Host "❌ $Name" -ForegroundColor $Colors.Error
            Log "$Name - FALHOU (exit=$LASTEXITCODE)"
        }
    } catch {
        Write-Host "❌ $Name - ERRO: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Log "$Name - ERRO: $($_.Exception.Message)"
    }
}

function ShowStatus {
    $done   = ($Tasks | Where-Object { $_.Done }).Count
    $total  = $Tasks.Count
    $percent = [math]::Round(($done / $total) * 100, 1)
    Write-Host "`n📊 Progresso: $done/$total ($percent%)" -ForegroundColor $Colors.Task
    foreach ($t in $Tasks) {
        $status = if ($t.Done) { "✅" } else { "⏳" }
        $color  = if ($t.Done) { $Colors.Done } else { $Colors.Warning }
        Write-Host "  $status $($t.Name)" -ForegroundColor $color
    }
}

function SaveJson {
    $json = $Tasks | ForEach-Object {
        [PSCustomObject]@{
            Tarefa = $_.Name
            Status = if ($_.Done) { "Concluído" } else { "Pendente" }
        }
    }
    $json | ConvertTo-Json -Depth 3 | Set-Content $JsonFile -Encoding UTF8
}

function SaveHtml {
    $rows = ($Tasks | ForEach-Object {
        $status = if ($_.Done) { "✅ Concluído" } else { "⏳ Pendente" }
        "<tr><td>$([System.Web.HttpUtility]::HtmlEncode($_.Name))</td><td>$status</td></tr>"
    }) -join "`n"
    $html = @"
<html>
<head>
<meta charset="utf-8"/>
<title>Relatório de Auditoria</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px}
table{border-collapse:collapse}
td,th{border:1px solid #ddd;padding:8px}
th{background:#f5f5f5}
</style>
</head>
<body>
<h2>Relatório de Auditoria - $(Get-Date)</h2>
<table>
<tr><th>Tarefa</th><th>Status</th></tr>
$rows
</table>
</body>
</html>
"@
    Set-Content $HtmlFile $html -Encoding UTF8
}

# =========================
# Helpers utilitários
# =========================
function Has($cmd) { try { Get-Command $cmd -ErrorAction Stop | Out-Null; $true } catch { $false } }

# =========================
# Helpers Postgres (saúde)
# =========================
function Get-FromEnvOrEnvFile([string]$Name, [string]$FallbackEnvFile) {
    # 1) Ambiente
    if ($env:${Name}) { return $env:${Name} }

    # 2) .env/.env.test
    if ($FallbackEnvFile -and (Test-Path $FallbackEnvFile)) {
        $line = (Get-Content $FallbackEnvFile | Where-Object { $_ -match "^\s*$([regex]::Escape($Name))\s*=" } | Select-Object -First 1)
        if ($line) {
            $value = $line -replace "^\s*$([regex]::Escape($Name))\s*=\s*", ""
            return $value.Trim('"').Trim("'")
        }
    }
    return $null
}

function Parse-PostgresUrl([string]$Url) {
    # postgresql://user:pass@host:port/db?schema=public
    $re = [regex]'postgresql:\/\/(?<user>[^:\/\s\?]+)(:(?<pass>[^@\/\s\?]*))?@(?<host>[^:\/\s\?]+)(:(?<port>\d+))?\/(?<db>[^?\s]+)'
    $m = $re.Match($Url)
    if (-not $m.Success) { throw "DATABASE_URL inválida ou não-parsável: $Url" }
    return [PSCustomObject]@{
        user = $m.Groups['user'].Value
        pass = $m.Groups['pass'].Value
        host = $m.Groups['host'].Value
        port = if ($m.Groups['port'].Success) { [int]$m.Groups['port'].Value } else { 5432 }
        db   = $m.Groups['db'].Value
    }
}

function Test-PostgresHealthy {
    param(
        [string]$ApiPathLocal,
        [string]$DockerContainerName = $env:PG_DOCKER_NAME # opcional
    )

    # Resolve DATABASE_URL
    $envFile = Join-Path $ApiPathLocal ".env.test"
    $dbUrl = Get-FromEnvOrEnvFile -Name "DATABASE_URL" -FallbackEnvFile $envFile
    if (-not $dbUrl) { throw "DATABASE_URL não encontrada no ambiente nem em $envFile" }

    $pg = Parse-PostgresUrl $dbUrl

    # pg_isready local
    if (Has "pg_isready") {
        $args = @("-h", $pg.host, "-p", "$($pg.port)", "-d", $pg.db, "-U", $pg.user, "-t", "5")
        & pg_isready @args
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    # Docker
    if (Has "docker") {
        if ($DockerContainerName) {
            $status = (docker inspect --format='{{.State.Health.Status}}' $DockerContainerName 2>$null)
            if ($LASTEXITCODE -eq 0 -and $status -eq "healthy") { return $true }

            docker exec $DockerContainerName pg_isready -h 127.0.0.1 -p $pg.port -d $pg.db -U $pg.user -t 5 2>$null
            if ($LASTEXITCODE -eq 0) { return $true }
        } else {
            $cid = (docker ps --filter "health=healthy" --format "{{.ID}} {{.Image}} {{.Names}}" | Select-String "postgres" | Select-Object -First 1)
            if ($cid) { return $true }
        }
    }

    return $false
}

# =========================
# Helpers App (start/stop/health)
# =========================
$global:APP_PROC = $null

function Get-PackageJson($apiPath) {
    $pkgPath = Join-Path $apiPath "package.json"
    if (-not (Test-Path $pkgPath)) { throw "package.json não encontrado em $apiPath" }
    return (Get-Content $pkgPath -Raw | ConvertFrom-Json)
}

function Resolve-HealthUrl([string]$ApiPathLocal, [string]$GivenUrl) {
    if ($GivenUrl) { return $GivenUrl }
    $envFile = Join-Path $ApiPathLocal ".env"
    $envTest = Join-Path $ApiPathLocal ".env.test"
    $port = $env:PORT
    if (-not $port) {
        $port = (Get-FromEnvOrEnvFile -Name "PORT" -FallbackEnvFile $envTest)
        if (-not $port) { $port = (Get-FromEnvOrEnvFile -Name "PORT" -FallbackEnvFile $envFile) }
        if (-not $port) { $port = "3000" }
    }
    return "http://127.0.0.1:$port/healthz"
}

function Wait-Healthy([string]$Url, [int]$Retries, [int]$TimeoutSec) {
    for ($i = 1; $i -le $Retries; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) { return $true }
        } catch { Start-Sleep -Seconds 1 }
    }
    return $false
}

function Start-AppServer([string]$ApiPathLocal, [string]$Cmd, [switch]$Verbose) {
    $pkg = Get-PackageJson $ApiPathLocal
    $startCmd = $Cmd
    if (-not $startCmd) {
        if ($pkg.scripts.PSObject.Properties.Name -contains "start") {
            $startCmd = "npm run start"
        } elseif ($pkg.scripts.PSObject.Properties.Name -contains "dev") {
            $startCmd = "npm run dev"
        } else {
            throw "Nenhum script 'start'/'dev' encontrado e AppStart não foi informado."
        }
    }

    Push-Location $ApiPathLocal
    try {
        if ($Verbose) {
            $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command",$startCmd -PassThru -WindowStyle Hidden
        } else {
            $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command",$startCmd ^|^| exit $LASTEXITCODE -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\mag_app_out.log" -RedirectStandardError "$env:TEMP\mag_app_err.log"
        }
        $global:APP_PROC = $p
        return $p
    } finally {
        Pop-Location
    }
}

function Stop-AppServer {
    if ($null -ne $global:APP_PROC) {
        try {
            Stop-Process -Id $global:APP_PROC.Id -Force -ErrorAction SilentlyContinue
        } catch {}
        $global:APP_PROC = $null
    }
}

# =========================
# Execução
# =========================
Execute "Verificar estrutura" "structure" {
    if (-not (Test-Path $ApiPath)) { throw "Diretório 'api' não encontrado em $ProjectPath" }
    0
}

Execute "Verificar dependências" "deps" {
    In-Api {
        if ($ShowDetails) {
            npm i -D eslint @eslint/js typescript-eslint
        } else {
            npm i -D eslint @eslint/js typescript-eslint 2>&1 | Out-Null
        }
    }
}

Execute "Configurar ESLint" "config" {
    $cfg = @'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default [
  { ignores: ["dist/**", "node_modules/**", "coverage/**"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    languageOptions: {
      parserOptions: {
        project: "./tsconfig.json",
        tsconfigRootDir: __dirname,
      },
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-namespace": "off",
    }
  }
];
'@
    Set-Content (Join-Path $ApiPath "eslint.config.mjs") -Value $cfg -Encoding UTF8
    0
}

Execute "Executar TypeCheck" "typecheck" {
    In-Api {
        $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
        if ($pkg.scripts.PSObject.Properties.Name -contains "typecheck") {
            if ($ShowDetails) { npm run typecheck } else { npm run typecheck 2>&1 | Out-Null }
        } else {
            if ($ShowDetails) { npx tsc -p "./tsconfig.json" --noEmit } else { npx tsc -p "./tsconfig.json" --noEmit 2>&1 | Out-Null }
        }
    }
}

Execute "Executar Lint" "lint" {
    In-Api {
        $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
        if ($pkg.scripts.PSObject.Properties.Name -contains "lint") {
            if ($ShowDetails) { npm run lint } else { npm run lint 2>&1 | Out-Null }
        } else {
            if ($ShowDetails) {
                npx eslint . --ext .ts --report-unused-disable-directives --max-warnings=0 --no-warn-ignored
            } else {
                npx eslint . --ext .ts --report-unused-disable-directives --max-warnings=0 --no-warn-ignored 2>&1 | Out-Null
            }
        }
    }
}

# ---- Build (se existir) ----
Execute "Build (se existir script)" "build" {
    In-Api {
        $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
        if ($pkg.scripts.PSObject.Properties.Name -contains "build") {
            if ($ShowDetails) { npm run build } else { npm run build 2>&1 | Out-Null }
        } else {
            Write-Host "ℹ️ Sem script 'build' — pulando" -ForegroundColor $Colors.Info
        }
        0
    }
}

# ---- Check Postgres saudável (NÃO derruba/sobe nada) ----
Execute "Saúde do Postgres (pg_isready/docker)" "pg" {
    if (-not (Test-PostgresHealthy -ApiPathLocal $ApiPath)) {
        throw "Postgres não está pronto: verifique container/porta/pg_isready. Dica: defina PG_DOCKER_NAME se usar docker-compose."
    }
    0
}

# ---- Healthcheck PRE: sobe app e espera /healthz (ou URL custom) ----
Execute "Healthcheck (subir app antes dos testes)" "prehc" {
    $url = Resolve-HealthUrl -ApiPathLocal $ApiPath -GivenUrl $HealthUrl
    Start-AppServer -ApiPathLocal $ApiPath -Cmd $AppStart -Verbose:$ShowDetails | Out-Null
    if (-not (Wait-Healthy -Url $url -Retries $HealthRetries -TimeoutSec $HealthTimeoutSec)) {
        Stop-AppServer
        throw "App não ficou saudável em tempo hábil: $url"
    }
    0
}

# ---- Testes reais ----
Execute "Executar Testes (real DB)" "tests" {
    In-Api {
        if ($ShowDetails) { npm run test } else { npm run test 2>&1 | Out-Null }
    }
}

# ---- Healthcheck PÓS: confirma que continua saudável ----
Execute "Healthcheck (após testes)" "posthc" {
    $url = Resolve-HealthUrl -ApiPathLocal $ApiPath -GivenUrl $HealthUrl
    if (-not (Wait-Healthy -Url $url -Retries 5 -TimeoutSec $HealthTimeoutSec)) {
        throw "App não respondeu saúde após testes: $url"
    }
    0
}

# ---- Prisma status ----
Execute "Prisma migrate status" "migrate" {
    In-Api {
        if ($ShowDetails) { npx prisma migrate status } else { npx prisma migrate status 2>&1 | Out-Null }
    }
}

# ---- npm audit (APENAS AVISO) ----
Execute "npm audit (moderate+)" "audit" {
    In-Api {
        if ($ShowDetails) { npm audit --audit-level=moderate } else { npm audit --audit-level=moderate 2>&1 | Out-Null }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️ Vulnerabilidades detectadas (nível >= moderate)" -ForegroundColor $Colors.Warning
            Log "npm audit: vulnerabilidades detectadas"
            $global:LASTEXITCODE = 0
        }
    }
}

# ---- Diffs pendentes (pula se git não existir) ----
Execute "Verificar diffs pendentes" "diff" {
    In-Api {
        if (-not (Has "git")) {
            Write-Host "ℹ️ git não encontrado no PATH — pulando" -ForegroundColor $Colors.Info
            0; return
        }
        git update-index -q --refresh
        git diff --quiet
        if ($LASTEXITCODE -ne 0) { throw "Há alterações não commitadas." }
        0
    }
}

# ---- CI último run (gh) (pula se gh não existir) ----
Execute "CI (último run via gh)" "ci" {
    In-Api {
        if (-not (Has "gh")) {
            Write-Host "ℹ️ gh não encontrado no PATH — pulando" -ForegroundColor $Colors.Info
            0; return
        }
        if ($ShowDetails) { gh run list --limit 1 } else { gh run list --limit 1 2>&1 | Out-Null }
    }
}

# ---- Commit automático opcional ----
if ($AutoCommit) {
    Execute "Commit automático" "commit" {
        In-Api {
            if (-not (Has "git")) {
                Write-Host "ℹ️ git não encontrado no PATH — pulando commit" -ForegroundColor $Colors.Info
                0; return
            }
            git add -A
            git diff --cached --quiet
            if ($LASTEXITCODE -eq 0) {
                Write-Host "ℹ️ Nada para commitar" -ForegroundColor $Colors.Info
                0; return
            }
            git commit -m "chore(api): auditoria técnica concluída"
        }
    }
}

# =========================
# Finalização (encerra app se estiver rodando)
# =========================
Stop-AppServer

ShowStatus
SaveJson
if ($GenerateReport) { SaveHtml }

Write-Host "`n✅ Auditoria finalizada. Resultados salvos em:" -ForegroundColor $Colors.Success
Write-Host "  - $JsonFile"
if ($GenerateReport) { Write-Host "  - $HtmlFile" }
Write-Host "  - $LogFile"

