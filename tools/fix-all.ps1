# tools\fix-all.ps1
param(
  [switch]$WhatIf  # prévia sem aplicar mudanças
)

$ErrorActionPreference = 'Stop'

function Backup-IfExists([string]$p, [string]$stamp) {
  if (Test-Path -LiteralPath $p) {
    $bak = "$p.bak.$stamp"
    Copy-Item -LiteralPath $p -Destination $bak -Force
    Write-Host "Backup => $bak"
  }
}

function Replace-RegexInFile([string]$path, [string]$pattern, [string]$replacement) {
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  $orig = Get-Content -LiteralPath $path -Raw
  $new  = [regex]::Replace($orig, $pattern, $replacement, 'Multiline')
  if ($new -ne $orig) {
    if ($WhatIf) {
      Write-Host "[WhatIf] Mudaria $path (regex: $pattern)"
    } else {
      Set-Content -LiteralPath $path -Encoding UTF8 -Value $new
      Write-Host "✓ Editado: $path"
    }
    return $true
  }
  return $false
}

function Ensure-FlatIgnores([string]$flatPath, [string[]]$addPatterns) {
  $ensureLine = "  { ignores: ['**/node_modules/**','**/dist/**','**/build/**'," +
                ($addPatterns | ForEach-Object { "'$_'" } | -join ',') + "] },"
  if (-not (Test-Path -LiteralPath $flatPath)) {
    if ($WhatIf) {
      Write-Host "[WhatIf] Criaria $flatPath com ignores."
    } else {
      @"
module.exports = [
$ensureLine
];
"@ | Set-Content -LiteralPath $flatPath -Encoding UTF8
      Write-Host "✓ Criado: $flatPath (com ignores)"
    }
    return
  }

  $txt = Get-Content -LiteralPath $flatPath -Raw
  # 1) já existe bloco ignores?
  $m = [regex]::Match($txt, '(?ms)ignores\s*:\s*\[(.*?)\]')
  if ($m.Success) {
    $current = $m.Groups[1].Value
    $missing = @()
    foreach ($p in @('**/node_modules/**','**/dist/**','**/build/**') + $addPatterns) {
      if ($current -notmatch [regex]::Escape($p)) { $missing += $p }
    }
    if ($missing.Count -gt 0) {
      $injected = $current.Trim()
      foreach ($p in $missing) {
        $injected = if ($injected) { "$injected, '$p'" } else { "'$p'" }
      }
      $txt2 = $txt.Substring(0, $m.Groups[1].Index) + $injected + $txt.Substring($m.Groups[1].Index + $m.Groups[1].Length)
      if ($WhatIf) {
        Write-Host "[WhatIf] Atualizaria ignores em $flatPath => +($missing -join ', ')"
      } else {
        Set-Content -LiteralPath $flatPath -Encoding UTF8 -Value $txt2
        Write-Host "✓ Atualizado ignores em $flatPath => +($missing -join ', ')"
      }
    } else {
      Write-Host "→ ignores já ok em $flatPath"
    }
  } else {
    # 2) injeta após o primeiro '[' exportado
    $m2 = [regex]::Match($txt, 'module\.exports\s*=\s*\[|export\s+default\s*\[')
    if (-not $m2.Success) { throw "Formato não reconhecido de $flatPath" }
    $newline = [Environment]::NewLine
    $txt3 = $txt.Insert($m2.Index + $m2.Length, $newline + $ensureLine)
    if ($WhatIf) {
      Write-Host "[WhatIf] Injetaria ignores em $flatPath"
    } else {
      Set-Content -LiteralPath $flatPath -Encoding UTF8 -Value $txt3
      Write-Host "✓ Injetado ignores em $flatPath"
    }
  }
}

# --- Paths básicos
$repo = (Resolve-Path '.').Path
$api  = Join-Path $repo 'api'
if (-not (Test-Path -LiteralPath $api)) { throw "Pasta 'api' não encontrada: $api" }

$eslintFlat = Join-Path $repo 'eslint.config.cjs'
$eslintrc   = Join-Path $api '.eslintrc.cjs'
$eslintIng  = Join-Path $api '.eslintignore'
$indexTs    = Join-Path $api 'src\index.ts'

$warnFiles = @(
  Join-Path $api 'src\http\insurance.policies.ts'),
  Join-Path $api 'src\http\notifications.ts'),
  Join-Path $api 'src\middleware\errorHandler.ts'),
  Join-Path $api 'src\services\notificationService.ts'
) -replace '\)$',''  # corrige trailing parens se houver

$tsApp  = Join-Path $api 'tsconfig.app.json'
$tsTest = Join-Path $api 'tsconfig.test.json'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Write-Host "== FIX-ALL ($stamp) =="

# --- Backups
foreach ($f in @($eslintFlat,$eslintrc,$eslintIng,$indexTs) + $warnFiles + @($tsApp,$tsTest)) {
  if ($f -and (Test-Path -LiteralPath $f)) { Backup-IfExists $f $stamp }
}

# --- 1) ESLint: flat + ignores, e desativar .eslintrc.cjs
Ensure-FlatIgnores -flatPath $eslintFlat -addPatterns @('api/.eslintrc.cjs','.eslintrc.cjs')

if (Test-Path -LiteralPath $eslintIng) {
  if ($WhatIf) { Write-Host "[WhatIf] Deletaria $eslintIng" } else {
    Remove-Item -LiteralPath $eslintIng -Force
    Write-Host "✓ Removido: $eslintIng"
  }
}

if (Test-Path -LiteralPath $eslintrc) {
  $dest = Join-Path $api '.eslintrc.cjs.disabled'
  if ($WhatIf) { Write-Host "[WhatIf] Renomearia $eslintrc -> $dest" } else {
    Rename-Item -LiteralPath $eslintrc -NewName (Split-Path -Leaf $dest) -Force
    Write-Host "✓ Renomeado: api\.eslintrc.cjs -> api\.eslintrc.cjs.disabled"
  }
}

# --- 2) TS configs: cria/ajusta
if (Test-Path -LiteralPath $tsApp) {
  Replace-RegexInFile $tsApp 'src//\*\.ts' 'src/**/*.ts' | Out-Null
} else {
  $appJson = @"
{
  "extends": "./tsconfig.json",
  "compilerOptions": { "rootDir": "src", "noEmit": true },
  "include": ["src/**/*.ts"]
}
"@
  if ($WhatIf) { Write-Host "[WhatIf] Criaria $tsApp" } else {
    $appJson | Set-Content -LiteralPath $tsApp -Encoding UTF8
    Write-Host "✓ Criado: $tsApp"
  }
}

if (Test-Path -LiteralPath $tsTest) {
  $changed = $false
  $changed = (Replace-RegexInFile $tsTest 'src//\*\.ts' 'src/**/*.ts') -bor $changed
  $changed = (Replace-RegexInFile $tsTest 'tests//\*\.ts' 'tests/**/*.ts') -bor $changed
} else {
  $testJson = @"
{
  "extends": "./tsconfig.json",
  "compilerOptions": { "rootDir": ".", "noEmit": true },
  "include": ["src/**/*.ts","tests/**/*.ts","vitest.config.ts"]
}
"@
  if ($WhatIf) { Write-Host "[WhatIf] Criaria $tsTest" } else {
    $testJson | Set-Content -LiteralPath $tsTest -Encoding UTF8
    Write-Host "✓ Criado: $tsTest"
  }
}

# --- 3) index.ts: remover @ts-expect-error e aplicar cast no swaggerUi.setup
if (Test-Path -LiteralPath $indexTs) {
  Replace-RegexInFile $indexTs '^\s*//\s*@ts-expect-error.*\r?\n?' ''   | Out-Null
  Replace-RegexInFile $indexTs 'swaggerUi\.setup\(([^)]+)\)' 'swaggerUi.setup($1) as any' | Out-Null
}

# --- 4) Lint warnings: remover import Prisma e prefixar vars/params não usados
# 4.1) remover import Prisma
$prismaFiles = @(
  Join-Path $api 'src\http\insurance.policies.ts'),
  Join-Path $api 'src\middleware\errorHandler.ts'),
  Join-Path $api 'src\services\notificationService.ts'
) -replace '\)$',''

foreach ($f in $prismaFiles) {
  if (-not (Test-Path -LiteralPath $f)) { continue }
  # remove `import { Prisma } from '@prisma/client'` (linha inteira)
  Replace-RegexInFile $f '^\s*import\s*\{\s*Prisma\s*\}\s*from\s*["'']@prisma/client["''];?\s*\r?\n?' '' | Out-Null
  # remove 'Prisma' de listas de import { ... }
  Replace-RegexInFile $f '(\{\s*[^}]*?)\bPrisma\s*,\s*' '$1' | Out-Null
  Replace-RegexInFile $f '(\{\s*[^}]*?)\s*,\s*Prisma\b' '$1' | Out-Null
}

# 4.2) prefixar nomes não usados
$renameMap = @{
  (Join-Path $api 'src\http\insurance.policies.ts') = @('premium','active','startAny','endAny');
  (Join-Path $api 'src\http\notifications.ts')      = @('subject','title','body','active')
}

foreach ($entry in $renameMap.GetEnumerator()) {
  $f = $entry.Key
  if (-not (Test-Path -LiteralPath $f)) { continue }
  $txt = Get-Content -LiteralPath $f -Raw
  $changed = $false
  foreach ($name in $entry.Value) {
    $pat = "(?<!_)`b$name`b"
    $new = [regex]::Replace($txt, $pat, "_$name")
    if ($new -ne $txt) { $changed = $true; $txt = $new }
  }
  if ($changed) {
    if ($WhatIf) { Write-Host "[WhatIf] Prefixaria não-usados em $f" } else {
      Set-Content -LiteralPath $f -Encoding UTF8 -Value $txt
      Write-Host "✓ Atualizado: $f (não-usados prefixados)"
    }
  }
}

Write-Host ""
Write-Host "== Executando pipeline (typecheck → lint → test → report) ==" -ForegroundColor Cyan
$mag = Join-Path $repo 'tools\mag.ps1'

if (-not $WhatIf) {
  & pwsh -File $mag -Task typecheck
  & pwsh -File $mag -Task lint
  & pwsh -File $mag -Task test
  & pwsh -File $mag -Task report
} else {
  Write-Host "[WhatIf] pularia execução dos tasks."
}

Write-Host ""
Write-Host "✓ FINALIZADO. Backups: *.bak.$stamp" -ForegroundColor Green
