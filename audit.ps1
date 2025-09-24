param(
  [string]$ProjectPath = ".",
  [switch]$AutoCommit,
  [switch]$GenerateReport,
  [switch]$ShowDetails,
  [string]$AppStart = "",
  [string]$HealthUrl = "",
  [int]$HealthRetries = 30,
  [int]$HealthTimeoutSec = 2
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# ---------- Cores ----------
$Colors = @{ Success="Green"; Warning="Yellow"; Error="Red"; Info="Cyan"; Task="Magenta"; Done="DarkGreen" }

# ---------- Paths ----------
$ProjectPath = (Resolve-Path $ProjectPath).Path
$ApiPath     = Join-Path $ProjectPath "api"
$LogFile  = Join-Path $ProjectPath "audit.log"
$JsonFile = Join-Path $ProjectPath "audit-result.json"
$HtmlFile = Join-Path $ProjectPath "audit-report.html"
"" | Set-Content $LogFile -Encoding UTF8

# ---------- Helpers ----------
function Log([string]$m){ Add-Content $LogFile "$((Get-Date).ToString('s')) - $m" }
function Has([string]$cmd){ try{ Get-Command $cmd -ErrorAction Stop | Out-Null; $true }catch{ $false } }
function In-Api([ScriptBlock]$sb){ Push-Location $ApiPath; try{ & $sb } finally{ Pop-Location } }

function Get-EnvVar([string]$n){
  $v=[Environment]::GetEnvironmentVariable($n,'Process')
  if(-not $v){$v=[Environment]::GetEnvironmentVariable($n,'User')}
  if(-not $v){$v=[Environment]::GetEnvironmentVariable($n,'Machine')}
  return $v
}
function Get-FromEnvOrEnvFile([string]$Name,[string]$EnvFile){
  $val = Get-EnvVar $Name
  if($val){ return $val }
  if($EnvFile -and (Test-Path $EnvFile)){
    $line = Get-Content $EnvFile | Where-Object { $_ -match "^\s*$([regex]::Escape($Name))\s*=" } | Select-Object -First 1
    if($line){
      $value = $line -replace "^\s*$([regex]::Escape($Name))\s*=\s*",""
      return $value.Trim('"').Trim("'")
    }
  }
  return $null
}

# ---------- Postgres ----------
function Parse-PostgresUrl([string]$Url){
  $re=[regex]'postgresql:\/\/(?<user>[^:\/\s\?]+)(:(?<pass>[^@\/\s\?]*))?@(?<host>[^:\/\s\?]+)(:(?<port>\d+))?\/(?<db>[^?\s]+)'
  $m=$re.Match($Url); if(-not $m.Success){ throw "DATABASE_URL inválida: $Url" }
  [pscustomobject]@{
    user=$m.Groups['user'].Value
    pass=$m.Groups['pass'].Value
    host=$m.Groups['host'].Value
    port= if($m.Groups['port'].Success){ [int]$m.Groups['port'].Value } else { 5432 }
    db  = $m.Groups['db'].Value
  }
}

function Test-PostgresHealthy{
  param([string]$ApiPathLocal,[string]$DockerContainerName = (Get-EnvVar "PG_DOCKER_NAME"))
  $envFile = Join-Path $ApiPathLocal ".env.test"
  $dbUrl = Get-FromEnvOrEnvFile -Name "DATABASE_URL" -EnvFile $envFile
  if(-not $dbUrl){ throw "DATABASE_URL não encontrada no ambiente nem em $envFile" }
  $pg = Parse-PostgresUrl $dbUrl

  if(Has "pg_isready"){
    & pg_isready -h $pg.host -p "$($pg.port)" -d $pg.db -U $pg.user -t 5 2>$null
    if($LASTEXITCODE -eq 0){ return $true }
  }
  if(Has "docker"){
    if($DockerContainerName){
      $status = (docker inspect --format='{{.State.Health.Status}}' $DockerContainerName 2>$null)
      if($LASTEXITCODE -eq 0 -and $status -eq "healthy"){ return $true }
      docker exec $DockerContainerName pg_isready -h 127.0.0.1 -p $pg.port -d $pg.db -U $pg.user -t 5 2>$null
      if($LASTEXITCODE -eq 0){ return $true }
    } else {
      $any = docker ps --filter "health=healthy" --format "{{.Names}}" 2>$null | Where-Object { $_ -match "postgres|pg" } | Select-Object -First 1
      if($any){ return $true }
    }
  }
  return $false
}

# ---------- App (start/stop/health) ----------
$global:APP_PROC = $null

function Get-PackageJson($apiPath){
  $pkgPath = Join-Path $apiPath "package.json"
  if(-not (Test-Path $pkgPath)){ throw "package.json não encontrado em $apiPath" }
  Get-Content $pkgPath -Raw | ConvertFrom-Json
}
function Resolve-HealthUrl([string]$ApiPathLocal,[string]$GivenUrl){
  if($GivenUrl){ return $GivenUrl }
  $port = Get-EnvVar "PORT"
  if(-not $port){ $port = Get-FromEnvOrEnvFile -Name "PORT" -EnvFile (Join-Path $ApiPathLocal ".env.test") }
  if(-not $port){ $port = Get-FromEnvOrEnvFile -Name "PORT" -EnvFile (Join-Path $ApiPathLocal ".env") }
  if(-not $port){ $port = "3000" }
  "http://127.0.0.1:$port/healthz"
}
function Wait-Healthy([string]$Url,[int]$Retries,[int]$TimeoutSec){
  for($i=1;$i -le $Retries;$i++){
    try{
      $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
      if($r.StatusCode -ge 200 -and $r.StatusCode -lt 400){ return $true }
    } catch {
      if($ShowDetails){ Write-Host ("  ⏳ Tentativa {0}/{1}: {2}" -f $i,$Retries,$_.Exception.Message) -ForegroundColor $Colors.Warning }
    }
    if($i -lt $Retries){ Start-Sleep -Seconds ([math]::Min(2 + ([double]$i * 0.5), 10)) }
  }
  return $false
}
function Start-AppServer([string]$ApiPathLocal,[string]$Cmd,[switch]$Verbose){
  $pkg = Get-PackageJson $ApiPathLocal
  $startCmd = $Cmd
  if(-not $startCmd){
    if($pkg.scripts.PSObject.Properties.Name -contains "start"){ $startCmd = "npm run start" }
    elseif($pkg.scripts.PSObject.Properties.Name -contains "dev"){ $startCmd = "npm run dev" }
    else { throw "Nenhum script 'start'/'dev' encontrado e AppStart não foi informado." }
  }
  Push-Location $ApiPathLocal
  try{
    if($Verbose){
      $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command",$startCmd -PassThru -WindowStyle Hidden
    } else {
      $p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command",$startCmd ^|^| exit $LASTEXITCODE -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\mag_app_out.log" -RedirectStandardError "$env:TEMP\mag_app_err.log"
    }
    $global:APP_PROC = $p; return $p
  } finally { Pop-Location }
}
function Stop-AppServer{
  if($null -ne $global:APP_PROC){
    try{ Stop-Process -Id $global:APP_PROC.Id -Force -ErrorAction SilentlyContinue } catch {}
    $global:APP_PROC = $null
  }
}

# ---------- Tarefas ----------
$Tasks = @(
  @{ Name="Verificar estrutura";                      Key="structure";  Done=$false },
  @{ Name="Verificar dependências";                   Key="deps";       Done=$false },
  @{ Name="Executar TypeCheck";                       Key="typecheck";  Done=$false },
  @{ Name="Executar Lint";                            Key="lint";       Done=$false },
  @{ Name="Build (se existir script)";                Key="build";      Done=$false },
  @{ Name="Saúde do Postgres (pg_isready/docker)";    Key="pg";         Done=$false },
  @{ Name="Healthcheck (subir app antes dos testes)"; Key="prehc";      Done=$false },
  @{ Name="Executar Testes (real DB)";                Key="tests";      Done=$false },
  @{ Name="Healthcheck (após testes)";                Key="posthc";     Done=$false },
  @{ Name="Prisma migrate status";                    Key="migrate";    Done=$false },
  @{ Name="npm audit (moderate+)";                    Key="audit";      Done=$false },
  @{ Name="Verificar diffs pendentes";                Key="diff";       Done=$false },
  @{ Name="CI (último run via gh)";                   Key="ci";         Done=$false },
  @{ Name="Commit automático";                        Key="commit";     Done=$false }
)
$TaskTimes = @{}

function Execute($Name,$Key,[ScriptBlock]$Script){
  Write-Host ("🔄 {0}..." -f $Name) -ForegroundColor $Colors.Task
  $t0=Get-Date
  try{
    $null = & $Script
    $ok = $LASTEXITCODE -eq 0
    $dt=[math]::Round(((Get-Date)-$t0).TotalSeconds,2)
    $TaskTimes[$Key]=$dt
    if($ok){ Write-Host ("✅ {0} ({1}s)" -f $Name,$dt) -ForegroundColor $Colors.Success; ($Tasks|?{$_.Key -eq $Key}).Done=$true; Log "$Name - OK ($dt s)" }
    else   { Write-Host ("❌ {0}" -f $Name) -ForegroundColor $Colors.Error; Log "$Name - FALHOU (exit=$LASTEXITCODE)" }
  } catch {
    $dt=[math]::Round(((Get-Date)-$t0).TotalSeconds,2)
    $TaskTimes[$Key]=$dt
    Write-Host ("❌ {0} - ERRO: {1}" -f $Name,$_.Exception.Message) -ForegroundColor $Colors.Error
    Log ("$Name - ERRO: {0} ({1}s)" -f $_.Exception.Message,$dt)
  }
}

function ShowStatus{
  $done=($Tasks|?{$_.Done}).Count; $total=$Tasks.Count
  $pct= if($total){ [math]::Round($done/$total*100,1) } else { 0 }
  Write-Host ("`n📊 Progresso: {0}/{1} ({2}%)" -f $done,$total,$pct) -ForegroundColor $Colors.Task
  $barLen=30; $fill=[math]::Floor($pct/100*$barLen)
  $bar=("▓"* $fill)+("░"*($barLen-$fill))
  Write-Host ("[{0}] {1}%" -f $bar,$pct) -ForegroundColor $Colors.Info
  foreach($t in $Tasks){
    $flag=if($t.Done){"✅"}else{"⏳"}; $color=if($t.Done){$Colors.Done}else{$Colors.Warning}
    $secs=if($TaskTimes[$t.Key]){"  ⏱ "+$TaskTimes[$t.Key]+"s"}else{""}
    Write-Host ("  {0} {1}{2}" -f $flag,$t.Name,$secs) -ForegroundColor $color
  }
}

function SaveJson{
  $out=[pscustomobject]@{ Timestamp=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); Projeto=$ProjectPath; Tarefas=@() }
  foreach($t in $Tasks){
    $out.Tarefas += [pscustomobject]@{ Key=$t.Key; Tarefa=$t.Name; Status=$(if($t.Done){"Concluído"}else{"Pendente"}); Segs=$TaskTimes[$t.Key] }
  }
  $out | ConvertTo-Json -Depth 6 | Set-Content $JsonFile -Encoding UTF8
  Write-Host ("📄 JSON: {0}" -f $JsonFile) -ForegroundColor $Colors.Info
}
function SaveHtml{
  $rows = ($Tasks | ForEach-Object {
    $status=if($_.Done){"✅ Concluído"}else{"⏳ Pendente"}
    $secs=if($TaskTimes[$_.Key]){" ("+$TaskTimes[$_.Key]+"s)"}else{""}
    $class=if($_.Done){"success"}else{"pending"}
    "<tr class='$class'><td>$([System.Web.HttpUtility]::HtmlEncode($_.Name))</td><td>$status$secs</td></tr>"
  }) -join "`n"
  $done=($Tasks|?{$_.Done}).Count; $total=$Tasks.Count; $pct=if($total){[math]::Round($done/$total*100,1)}else{0}
  $html=@"
<!doctype html><html lang="pt-BR"><head>
<meta charset="utf-8"/><title>Relatório de Auditoria</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;background:#f5f7fa}
.container{max-width:900px;margin:0 auto;background:#fff;padding:30px;border-radius:12px;box-shadow:0 2px 12px rgba(0,0,0,.08)}
h1{color:#2c3e50;margin-top:0}
table{border-collapse:collapse;width:100%;margin-top:16px}
td,th{border:1px solid #e1e5ea;padding:10px}
th{background:#3498db;color:#fff;text-align:left}
.success{background:#eafaf1}.pending{background:#fff8e1}
.bar{height:14px;background:#ecf0f1;border-radius:8px;overflow:hidden}
.fill{height:100%;background:linear-gradient(90deg,#27ae60,#2ecc71);width:$pct%}
.meta{color:#7f8c8d}
</style>
</head><body><div class="container">
<h1>🚀 Auditoria mag-webapp-v10</h1>
<p class="meta">Projeto: $ProjectPath<br/>Gerado: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
<div class="bar"><div class="fill"></div></div>
<p><b>Progresso:</b> $done/$total ($pct%)</p>
<table><tr><th>Tarefa</th><th>Status</th></tr>
$rows
</table>
</div></body></html>
"@
  Set-Content $HtmlFile $html -Encoding UTF8
  Write-Host ("🌐 HTML: {0}" -f $HtmlFile) -ForegroundColor $Colors.Info
}

# ---------- Pré-checks ----------
if(-not (Test-Path $ApiPath)){ throw "Diretório 'api' não encontrado em $ProjectPath" }
if(-not (Has "node")){ throw "Node.js não está no PATH" }
if(-not (Has "npm")){ throw "npm não está no PATH" }

# ---------- Execução ----------
Execute "Verificar estrutura" "structure" {
  if(-not (Test-Path (Join-Path $ApiPath "package.json"))){ throw "package.json ausente em $ApiPath" }
  0
}
Execute "Verificar dependências" "deps" {
  In-Api { if(-not (Test-Path "node_modules")){ if($ShowDetails){ npm ci } else { npm ci 2>&1 | Out-Null } } }
}
Execute "Executar TypeCheck" "typecheck" {
  In-Api {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    if($pkg.scripts.PSObject.Properties.Name -contains "typecheck"){
      if($ShowDetails){ npm run typecheck } else { npm run typecheck 2>&1 | Out-Null }
    } else {
      if($ShowDetails){ npx tsc -p "./tsconfig.json" --noEmit } else { npx tsc -p "./tsconfig.json" --noEmit 2>&1 | Out-Null }
    }
  }
}
Execute "Executar Lint" "lint" {
  In-Api {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    if($pkg.scripts.PSObject.Properties.Name -contains "lint"){
      if($ShowDetails){ npm run lint } else { npm run lint 2>&1 | Out-Null }
    } else {
      if($ShowDetails){ npx eslint . --ext .ts --report-unused-disable-directives --max-warnings=0 --no-warn-ignored } else { npx eslint . --ext .ts --report-unused-disable-directives --max-warnings=0 --no-warn-ignored 2>&1 | Out-Null }
    }
  }
}
Execute "Build (se existir script)" "build" {
  In-Api {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    if($pkg.scripts.PSObject.Properties.Name -contains "build"){
      if($ShowDetails){ npm run build } else { npm run build 2>&1 | Out-Null }
    } else { Write-Host "ℹ️ Sem script 'build' — pulando" -ForegroundColor $Colors.Info }
    0
  }
}
Execute "Saúde do Postgres (pg_isready/docker)" "pg" {
  if(-not (Test-PostgresHealthy -ApiPathLocal $ApiPath)){ throw "Postgres não está pronto (verifique PG_DOCKER_NAME e .env.test)" }
  0
}
Execute "Healthcheck (subir app antes dos testes)" "prehc" {
  $url = Resolve-HealthUrl -ApiPathLocal $ApiPath -GivenUrl $HealthUrl
  Start-AppServer -ApiPathLocal $ApiPath -Cmd $AppStart -Verbose:$ShowDetails | Out-Null
  if(-not (Wait-Healthy -Url $url -Retries $HealthRetries -TimeoutSec $HealthTimeoutSec)){ Stop-AppServer; throw "App não ficou saudável: $url" }
  0
}
Execute "Executar Testes (real DB)" "tests" {
  In-Api {
    $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
    if($pkg.scripts.PSObject.Properties.Name -contains "test"){
      if($ShowDetails){ npm run test } else { npm run test 2>&1 | Out-Null }
    } else { Write-Host "ℹ️ Sem script 'test' — pulando" -ForegroundColor $Colors.Info }
  }
}
Execute "Healthcheck (após testes)" "posthc" {
  $url = Resolve-HealthUrl -ApiPathLocal $ApiPath -GivenUrl $HealthUrl
  if(-not (Wait-Healthy -Url $url -Retries 5 -TimeoutSec $HealthTimeoutSec)){ Write-Host "⚠️ App não respondeu saúde após testes" -ForegroundColor $Colors.Warning }
  Stop-AppServer
  0
}
Execute "Prisma migrate status" "migrate" { In-Api { if($ShowDetails){ npx prisma migrate status } else { npx prisma migrate status 2>&1 | Out-Null } } }
Execute "npm audit (moderate+)" "audit"   { In-Api { if($ShowDetails){ cmd /c "npm audit --audit-level=moderate || exit /b 0" } else { cmd /c "npm audit --audit-level=moderate || exit /b 0" 2>&1 | Out-Null } }; $global:LASTEXITCODE=0 }
Execute "Verificar diffs pendentes" "diff"{
  In-Api {
    if(-not (Has "git")){ Write-Host "ℹ️ git não encontrado — pulando" -ForegroundColor $Colors.Info; 0; return }
    git update-index -q --refresh; git diff --quiet
    if($LASTEXITCODE -ne 0){ throw "Há alterações não commitadas." }
    0
  }
}
Execute "CI (último run via gh)" "ci"{
  In-Api {
    if(-not (Has "gh")){ Write-Host "ℹ️ gh não encontrado — pulando" -ForegroundColor $Colors.Info; 0; return }
    if($ShowDetails){ gh run list --limit 1 } else { gh run list --limit 1 2>&1 | Out-Null }
  }
}
if($AutoCommit){
  Execute "Commit automático" "commit" {
    In-Api {
      if(-not (Has "git")){ Write-Host "ℹ️ git não encontrado — pulando commit" -ForegroundColor $Colors.Info; 0; return }
      git add -A; git diff --cached --quiet
      if($LASTEXITCODE -eq 0){ Write-Host "ℹ️ Nada para commitar" -ForegroundColor $Colors.Info; 0; return }
      git commit -m ("chore(api): auditoria técnica concluída em {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    }
  }
}

# ---------- Relatórios ----------
function ShowStatusBrief {
  $done=($Tasks|?{$_.Done}).Count; $total=$Tasks.Count; $pct=if($total){[math]::Round($done/$total*100,1)}else{0}
  Write-Host ("`n📋 Auditoria: {0}/{1} ({2}%)" -f $done,$total,$pct) -ForegroundColor $Colors.Info
}
ShowStatus
SaveJson
if($GenerateReport){ SaveHtml }
ShowStatusBrief
Write-Host "`n✅ Auditoria finalizada. Logs em: $LogFile" -ForegroundColor $Colors.Success

