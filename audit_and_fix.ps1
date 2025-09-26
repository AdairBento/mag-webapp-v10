# audit_and_fix.ps1
# Faz tudo: garante git no PATH, corrige husky/lint-staged,
# conserta imports do Express.Router, garante .gitignore, roda typecheck,
# commita e dá push (use -NoPush p/ só commitar).

[CmdletBinding()]
param(
  [switch]$NoPush
)

function Ensure-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) { return }
  $gitDirs = @(
    "C:\Program Files\Git\cmd",
    "C:\Program Files\Git\bin",
    "$env:LOCALAPPDATA\Programs\Git\cmd",
    "$env:LOCALAPPDATA\Programs\Git\bin"
  )
  foreach($d in $gitDirs){ if(Test-Path $d){ $env:PATH += ";$d" } }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git não encontrado no PATH. Instale o Git for Windows ou adicione ao PATH."
  }
}

function Ensure-AtRepoRoot {
  $top = (& git rev-parse --show-toplevel) 2>$null
  if (-not $top) { throw "Não parece ser um repositório git. Rode na raiz do projeto." }
  if ((Resolve-Path ".").Path -ne $top) { Set-Location $top }
}

function Normalize-LF([string]$path) {
  if (-not (Test-Path $path)) { return }
  $c = Get-Content $path -Raw -EA SilentlyContinue
  if ($null -ne $c) { [IO.File]::WriteAllText($path, ($c -replace "`r?`n","`n")) }
}

function Setup-HuskyLintStaged {
  Write-Host "✔ Configurando husky + lint-staged…"
  New-Item -ItemType Directory -Path ".husky" -Force | Out-Null
  $hook = @'
# husky v9+ (sem shebang)
set -e
cd api
npx --no-install lint-staged || npx --yes lint-staged
'@
  [IO.File]::WriteAllText(".husky/pre-commit", ($hook -replace "`r?`n","`n"))

  $apiPkgPath = "api\package.json"
  if (-not (Test-Path $apiPkgPath)) { throw "api\package.json não encontrado." }
  $api = Get-Content $apiPkgPath -Raw | ConvertFrom-Json

  if (-not ($api.PSObject.Properties.Name -contains 'lint-staged')) {
    $api | Add-Member -NotePropertyName 'lint-staged' -NotePropertyValue ([PSCustomObject]@{}) -Force
  }

  # comando usado pelo lint-staged
  $cmd = 'npx --no-install eslint --fix --cache --config ../eslint.config.cjs || npx --yes eslint --fix --cache --config ../eslint.config.cjs'
  $ls = $api.PSObject.Properties['lint-staged'].Value
  $ls | Add-Member -NotePropertyName 'src/**/*.{ts,tsx}' -NotePropertyValue $cmd -Force

  ($api | ConvertTo-Json -Depth 100) | Set-Content $apiPkgPath -Encoding UTF8
  Normalize-LF ".husky/pre-commit"
}

function Fix-ExpressRouterImports {
  Write-Host "✔ Corrigindo imports de Express.Router…"
  $apiSrc = Join-Path (Resolve-Path "api").Path "src"
  if (-not (Test-Path $apiSrc)) { return }
  $files = Get-ChildItem -Path $apiSrc -Recurse -Filter *.ts
  foreach ($f in $files) {
    $orig = Get-Content $f.FullName -Raw
    $txt = $orig

    $re1 = @"
(?m)^\s*import\s+type\s*\{\s*([^}]*?\bRouter\b[^}]*)\}\s*from\s*["']express["']\s*;\s*
"@
    $txt = [regex]::Replace($txt, $re1,
      {
        param($m)
        $names = $m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $vals = @(); $types = @()
        foreach($n in $names){ if ($n -eq 'Router') { $vals += 'Router' } else { $types += $n } }
        $out = @()
        if ($vals.Count -gt 0 -and ($orig -notmatch '(?m)^\s*import\s*\{\s*Router\s*\}\s*from\s*["'']express["'']\s*;')) {
          $out += 'import { Router } from "express";'
        }
        if ($types.Count -gt 0) {
          $out += 'import type { ' + ($types -join ', ') + ' } from "express";'
        }
        [string]::Join("`n", $out) + "`n"
      })

    $re2 = @"
(?m)^\s*import\s+type\s*\{\s*Router\s*\}\s*from\s*["']express["']\s*;\s*
"@
    $txt = [regex]::Replace($txt, $re2,
      {
        if ($orig -match '(?m)^\s*import\s*\{\s*Router\s*\}\s*from\s*["'']express["'']\s*;') { '' }
        else { 'import { Router } from "express";' }
      })

    if ($txt -ne $orig) {
      Set-Content $f.FullName $txt -Encoding UTF8
      Write-Host "  fix: $($f.FullName)"
    }
  }
}

function Ensure-GitignoreBlock {
  Write-Host "✔ Garantindo blocos no .gitignore…"
  $block = @"
# audit e backups
*.bak
/audit-*.html
/audit-result.json
/audit.backup*.ps1
!audit_project.ps1
"@
  if (-not (Test-Path .gitignore)) { New-Item -ItemType File -Path .gitignore | Out-Null }
  $gi = Get-Content .gitignore -Raw
  if ($gi -notmatch '(?ms)^# audit e backups\b') {
    Add-Content -Path .gitignore -Value "`r`n$block"
  }
}

function Run-Typecheck {
  Write-Host "✔ Rodando typecheck da API…"
  pushd api | Out-Null
  try {
    npm run -s typecheck
  } finally {
    popd | Out-Null
  }
}

function Stage-Commit-Push {
  Write-Host "✔ Preparando commit…"
  $patterns = @(
    ".husky/pre-commit",
    "api/package.json",
    "api/src/**/*.ts",
    ".gitignore",
    "eslint.config.cjs",
    ".github/workflows/ci.yml"
  )
  foreach($p in $patterns){ git add $p 2>$null }

  $status = git status --porcelain
  if (-not $status) { Write-Host "Nada para commitar."; return }

  git commit -m "chore(api): auto-audit — Router import, lint-staged e .gitignore" | Out-Null

  if ($PSBoundParameters.ContainsKey('NoPush')) {
    Write-Host "Commit feito. Push desabilitado por -NoPush."
  } else {
    Write-Host "✔ Dando push…"
    git push
  }
}

# -------- MAIN --------
try {
  Ensure-Git
  Ensure-AtRepoRoot

  Write-Host "Git:  $(git --version)"
  Write-Host "Node: $(node -v)  npm: $(npm -v)"
  Write-Host "Branch: $(git rev-parse --abbrev-ref HEAD)"

  Setup-HuskyLintStaged
  Fix-ExpressRouterImports
  Ensure-GitignoreBlock
  Run-Typecheck
  Stage-Commit-Push

  Write-Host "`n✅ Pronto."
  Write-Host "Se o push barrar no pre-push/typecheck, veja o erro mostrado acima."
} catch {
  Write-Error $_
  exit 1
}
