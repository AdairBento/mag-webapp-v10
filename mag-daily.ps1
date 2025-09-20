<#  mag-daily.ps1
    Workflow diário para o MAG:
    - Sobe/recupera a API (mag-up)
    - Cria/garante um cliente de teste (Ensure-Client)
    - Lista veículos (GET /api/v1/vehicles)
    - Mostra status de locações do primeiro veículo (Show-RentalStatus)
#>

[CmdletBinding()]
param(
  [string]$Repo     = "C:\Users\adair\PycharmProjects\mag-webapp-v10",
  [string]$ApiPath  = "api",
  [string]$Base     = "http://127.0.0.1:3000",
  [string]$TenantId = "dev",
  [int]$Port        = 3000,
  [string]$StartCmd = "npm run dev",

  # “Seed” de cliente para testes rápidos
  [string]$SeedEmail = "cliente.demo@mag.dev",
  [string]$SeedName  = "Cliente Demo"
)

$ErrorActionPreference = 'Stop'

function _ok($msg){ Write-Host $msg -ForegroundColor Green }
function _info($msg){ Write-Host $msg -ForegroundColor Cyan }
function _warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function _err($msg){ Write-Host $msg -ForegroundColor Red }

try {
  _info "🔧 Ajustando contexto…"
  Set-MagContext -Base $Base -Tenant $TenantId
  _ok   "Contexto: $(Get-MagContext | Out-String)"

  _info "🚀 Subindo/recuperando API…"
  mag-up -Repo $Repo -ApiPath $ApiPath -Port $Port -StartCmd $StartCmd -Base $Base -TenantId $TenantId

  _info "👤 Garantindo cliente de teste…"
  $client = Ensure-Client -email $SeedEmail -name $SeedName
  _ok     "Cliente OK: $($client.id)  ($($client.email))"

  _info "🚗 Buscando veículos…"
  $vehiclesResp = GetJson "/api/v1/vehicles"
  $vehicles = $vehiclesResp.data
  if (-not $vehicles -or $vehicles.Count -eq 0) {
    _warn "Nenhum veículo encontrado. (Cadastre um veículo para testar locações)"
  } else {
    $v = $vehicles | Select-Object -First 1
    _ok "1º veículo: $($v.id) — $($v.plate ?? $v.name ?? '(sem identificação)')"
    _info "📊 Status de locações do veículo:"
    Show-RentalStatus -vehicleId $v.id
  }

  _info "✅ Pronto! Fluxo diário executado."
  _info "Dicas:"
  Write-Host " • Chamar endpoints:   GetJson '/api/v1/rentals'"
  Write-Host " • Contexto atual:     Get-MagContext"
  Write-Host " • Mudar contexto:     Set-MagContext -Base '$Base' -Tenant '$TenantId'"

} catch {
  _err "Falhou: $($_.Exception.Message)"
  if ($_.ScriptStackTrace) { _warn $_.ScriptStackTrace }
  exit 1
}
