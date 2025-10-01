# ===========================
# MAG helpers (PowerShell)
# ===========================

# Contexto (porta + tenant)
function Set-MagContext {
  param([int]$Port, [string]$Tenant)
  $script:MagPort   = $Port
  $script:MagTenant = $Tenant
  Write-Host "Contexto -> PORT=$Port | TENANT=$Tenant"
}

# Encoder para querystrings (robusto)
Add-Type -AssemblyName System.Web | Out-Null
function UrlEncode([string]$s) { [System.Web.HttpUtility]::UrlEncode($s) }

# Token (rota pública)
function Get-Token {
  $body = @{ sub="admin@mag.dev"; tenantId=$script:MagTenant; roles=@("admin"); ttl="12h" } | ConvertTo-Json
  (Invoke-RestMethod -Method Post -Uri "http://localhost:$($script:MagPort)/api/auth/token" `
    -ContentType "application/json" -Body $body).token
}

# Listar clientes (com q=? opcional)
function Get-Clients {
  param([Parameter(Mandatory=$true)][string]$Token, [string]$Query)
  $builder = [System.UriBuilder]::new()
  $builder.Scheme = "http"; $builder.Host = "localhost"; $builder.Port = $script:MagPort; $builder.Path = "api/clients"
  if ($Query) { $builder.Query = "q=$(UrlEncode($Query))" }
  $uri = $builder.Uri.AbsoluteUri
  Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $Token"; "x-tenant-id" = $script:MagTenant }
}

# Buscar cliente por ID
function Get-ClientById {
  param([Parameter(Mandatory=$true)][string]$Token, [Parameter(Mandatory=$true)][string]$Id)
  $uri = "http://localhost:$($script:MagPort)/api/clients/$Id"
  Invoke-RestMethod -Uri $uri -Headers @{ Authorization="Bearer $Token"; "x-tenant-id"=$script:MagTenant }
}

# Criar cliente
function New-Client {
  param(
    [Parameter(Mandatory=$true)][string]$Token,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Email,
    [Parameter(Mandatory=$true)][string]$Phone,
    [string]$Document,
    [switch]$WhatsappOptIn
  )
  $payload = @{ tenantId=$script:MagTenant; name=$Name; email=$Email; phone=$Phone }
  if ($Document) { $payload.document = $Document }
  if ($WhatsappOptIn) { $payload.whatsappOptIn = $true }
  $json = $payload | ConvertTo-Json
  Invoke-RestMethod -Method Post `
    -Headers @{ Authorization="Bearer $Token"; "x-tenant-id"=$script:MagTenant } `
    -ContentType "application/json" `
    -Uri "http://localhost:$($script:MagPort)/api/clients" `
    -Body $json
}

# Atualizar (PUT)
function Update-Client {
  param(
    [Parameter(Mandatory=$true)][string]$Token,
    [Parameter(Mandatory=$true)][string]$Id,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Email,
    [Parameter(Mandatory=$true)][string]$Phone,
    [string]$Document,
    [Nullable[bool]]$WhatsappOptIn
  )
  $payload = @{ name=$Name; email=$Email; phone=$Phone }
  if ($PSBoundParameters.ContainsKey('Document'))      { $payload.document = $Document }
  if ($PSBoundParameters.ContainsKey('WhatsappOptIn')) { $payload.whatsappOptIn = $WhatsappOptIn }
  $json = $payload | ConvertTo-Json
  Invoke-RestMethod -Method Put `
    -Headers @{ Authorization="Bearer $Token"; "x-tenant-id"=$script:MagTenant } `
    -ContentType "application/json" `
    -Uri "http://localhost:$($script:MagPort)/api/clients/$Id" `
    -Body $json
}

# Atualizar parcial (PATCH)
function Patch-Client {
  param(
    [Parameter(Mandatory=$true)][string]$Token,
    [Parameter(Mandatory=$true)][string]$Id,
    [string]$Name, [string]$Email, [string]$Phone, [string]$Document,
    [Nullable[bool]]$WhatsappOptIn
  )
  $payload = @{}
  if ($PSBoundParameters.ContainsKey('Name'))          { $payload.name          = $Name }
  if ($PSBoundParameters.ContainsKey('Email'))         { $payload.email         = $Email }
  if ($PSBoundParameters.ContainsKey('Phone'))         { $payload.phone         = $Phone }
  if ($PSBoundParameters.ContainsKey('Document'))      { $payload.document      = $Document }
  if ($PSBoundParameters.ContainsKey('WhatsappOptIn')) { $payload.whatsappOptIn = $WhatsappOptIn }
  if ($payload.Count -eq 0) { throw "Informe ao menos um campo para PATCH." }
  $json = $payload | ConvertTo-Json
  Invoke-RestMethod -Method Patch `
    -Headers @{ Authorization="Bearer $Token"; "x-tenant-id"=$script:MagTenant } `
    -ContentType "application/json" `
    -Uri "http://localhost:$($script:MagPort)/api/clients/$Id" `
    -Body $json
}

# Remover
function Remove-Client {
  param([Parameter(Mandatory=$true)][string]$Token, [Parameter(Mandatory=$true)][string]$Id)
  Invoke-RestMethod -Method Delete `
    -Headers @{ Authorization="Bearer $Token"; "x-tenant-id"=$script:MagTenant } `
    -Uri "http://localhost:$($script:MagPort)/api/clients/$Id"
}
