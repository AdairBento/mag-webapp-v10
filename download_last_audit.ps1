[CmdletBinding()]
param(
  [string]$Branch       = "main",
  [string]$ArtifactName = "audit_report",
  [string]$OutDir       = ".\artifact"
)

$ErrorActionPreference = "Stop"

function Get-OwnerRepo {
  $url = (git remote get-url origin) 2>$null
  if (-not $url) { throw "Não foi possível obter a URL do remoto 'origin'." }
  if ($url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)') {
    return @($Matches['owner'], $Matches['repo'])
  }
  throw "Remoto 'origin' não parece ser do GitHub: $url"
}

try {
  $pair = Get-OwnerRepo
  $owner = $pair[0]; $repo = $pair[1]
  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

  $useGh = $false
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    # Evita que tokens de ambiente quebrem o login do gh
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
    try { gh auth status -h github.com *> $null; $useGh = $true } catch { $useGh = $false }
  }

  if ($useGh) {
    Write-Host "✔ Usando GitHub CLI (gh)…"
    $slug = "$owner/$repo"
    $ids = gh run list -R $slug -b $Branch -L 30 --json databaseId --jq ".[].databaseId"
    if (-not $ids) { throw "Nenhum run encontrado na branch $Branch." }
    $found = $false
    foreach($id in $ids){
      try {
        gh run download $id -R $slug -n $ArtifactName -D $OutDir
        $found = $true; break
      } catch {}
    }
    if (-not $found) { throw "Artifact '$ArtifactName' não encontrado nos últimos runs da $Branch." }
  } else {
    Write-Host "ℹ️  gh indisponível. Usando API…"
    $token = $env:GH_TOKEN; if (-not $token) { $token = $env:GITHUB_TOKEN }
    if (-not $token) { $token = Read-Host -Prompt "Cole seu GH_TOKEN (Actions:read + Contents:read)" }
    if (-not $token) { throw "Token não informado." }

    $Headers = @{
      Authorization          = "Bearer $token"
      "X-GitHub-Api-Version" = "2022-11-28"
      Accept                 = "application/vnd.github+json"
      "User-Agent"           = "PowerShell"
    }

    $runs = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$owner/$repo/actions/runs?branch=$Branch&per_page=30"
    $runIds = $runs.workflow_runs.id
    if (-not $runIds) { throw "Nenhum run encontrado na branch $Branch." }

    $found = $false
    foreach($rid in $runIds){
      $arts = Invoke-RestMethod -Headers $Headers -Uri "https://api.github.com/repos/$owner/$repo/actions/runs/$rid/artifacts"
      $artifact = $arts.artifacts | Where-Object name -eq $ArtifactName
      if ($artifact) {
        $zipUrl  = $artifact.archive_download_url
        $zipPath = Join-Path $OutDir "$ArtifactName.zip"
        Invoke-WebRequest -Headers @{ Authorization = "Bearer $token"; "User-Agent"="PowerShell"; Accept="*/*" } -Uri $zipUrl -OutFile $zipPath
        Expand-Archive $zipPath -DestinationPath (Join-Path $OutDir $ArtifactName) -Force
        $found = $true; break
      }
    }
    if (-not $found) { throw "Artifact '$ArtifactName' não encontrado nos últimos runs da $Branch." }
  }

  $html = Join-Path (Join-Path $OutDir $ArtifactName) "audit-report.html"
  if (Test-Path $html) { Start-Process $html } else { Write-Host "Baixado em: $OutDir\$ArtifactName" }
} catch {
  Write-Error $_
  exit 1
}
