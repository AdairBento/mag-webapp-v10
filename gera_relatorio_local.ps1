[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Ensure-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) { return }
  $cands = @(
    "$Env:ProgramFiles\Git\cmd",
    "$Env:ProgramFiles\Git\bin",
    "$Env:LOCALAPPDATA\Programs\Git\cmd",
    "$Env:LOCALAPPDATA\Programs\Git\bin"
  )
  foreach($d in $cands){ if(Test-Path $d){ $env:PATH += ";$d" } }
}

function HtmlEncode([string]$s){
  try {
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    return [System.Web.HttpUtility]::HtmlEncode($s)
  } catch {
    return [System.Net.WebUtility]::HtmlEncode($s)
  }
}

# --- preparação ---
$outDir = ".\artifact\audit_report"
$null = New-Item -ItemType Directory -Path $outDir -Force
$log   = Join-Path $outDir "audit-log.txt"
$html  = Join-Path $outDir "audit-report.html"

# --- garante git no PATH ---
Ensure-Git

# --- infos do repo/branch (com fallback) ---
$repoTop = try { git rev-parse --show-toplevel } catch { "(N/A)" }
$branch  = try { git rev-parse --abbrev-ref HEAD } catch { "(N/A)" }

"Repo: $repoTop"                     | Out-File $log -Encoding UTF8
"Branch: $branch"                   | Out-File $log -Append -Encoding UTF8
"Node: $(node -v)  npm: $(npm -v)"  | Out-File $log -Append -Encoding UTF8
"`n== API typecheck =="             | Out-File $log -Append -Encoding UTF8

# --- typecheck da API ---
pushd api | Out-Null
try {
  npm run -s typecheck 2>&1 | Tee-Object -FilePath $log -Append | Out-Null
} finally { popd | Out-Null }

# --- HTML + abrir ---
$enc = HtmlEncode (Get-Content $log -Raw)
@"
<!doctype html><meta charset="utf-8">
<title>Audit Report</title>
<h1>Audit Report</h1>
<p>Gerado em $(Get-Date -Format s)</p>
<pre>$enc</pre>
"@ | Set-Content $html -Encoding UTF8

Start-Process $html
Write-Host "OK: $html"
