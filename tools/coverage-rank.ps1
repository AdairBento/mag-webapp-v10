param(
[string]$ApiDir = (Join-Path (Resolve-Path ".") "api")
)
$finFile = Join-Path $ApiDir "coverage\coverage-final.json"
if (-not (Test-Path $finFile)) { Write-Error "coverage-final.json não encontrado. Rode 'npm --prefix api run test:cov' antes."; exit 1 }
$cf = Get-Content $finFile -Raw | ConvertFrom-Json -AsHashtable
$rows = foreach ($kv in $cf.GetEnumerator()) {
  if ($kv.Key -eq 'total') { continue }
  $v = $kv.Value
  if ($null -ne $v -and $v.ContainsKey('branches')) {
    [PSCustomObject]@{
      File      = $kv.Key
      BranchPct = [math]::Round([double]$v.branches.pct,2)
      LinesPct  = [math]::Round([double]$v.lines.pct,2)
      FuncPct   = [math]::Round([double]$v.functions.pct,2)
      StmtsPct  = [math]::Round([double]$v.statements.pct,2)
    }
  }
}
$rows | Sort-Object BranchPct, LinesPct | Select-Object -First 12 |
  Format-Table @{n='Branch%';e={$_.BranchPct}},
               @{n='Lines%'; e={$_.LinesPct}},
               @{n='Func%';  e={$_.FuncPct}},
               @{n='Stmt%';  e={$_.StmtsPct}},
               @{n='Arquivo';e={$_.File}} -AutoSize