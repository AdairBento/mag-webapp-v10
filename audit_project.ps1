param(
  [string]$ProjectPath = ".",
  [string]$ReportFile = "audit_report.csv"
)

# Resolver caminho absoluto do projeto
$ProjectPath = (Resolve-Path $ProjectPath).Path
$ApiPath = Join-Path $ProjectPath "api"

# Itens essenciais esperados no projeto
$expectedItems = @(
  @{ Path = $ApiPath; Description = "Pasta api/"; Type = "Directory" },
  @{ Path = Join-Path $ApiPath "package.json"; Description = "api/package.json"; Type = "File" },
  @{ Path = Join-Path $ApiPath "tsconfig.json"; Description = "api/tsconfig.json"; Type = "File" },
  @{ Path = Join-Path $ApiPath "node_modules"; Description = "api/node_modules/"; Type = "Directory" },
  @{ Path = Join-Path $ApiPath "package-lock.json"; Description = "api/package-lock.json"; Type = "File" },
  @{ Path = Join-Path $ApiPath ".env"; Description = "api/.env"; Type = "File" },
  @{ Path = Join-Path $ApiPath ".env.example"; Description = "api/.env.example"; Type = "File" },
  @{ Path = Join-Path $ApiPath ".env.test"; Description = "api/.env.test"; Type = "File" },
  @{ Path = Join-Path $ApiPath "src"; Description = "api/src/"; Type = "Directory" },
  @{ Path = Join-Path $ApiPath "src/http/app.ts"; Description = "api/src/http/app.ts"; Type = "File" },
  @{ Path = Join-Path $ApiPath "src/server.ts"; Description = "api/src/server.ts"; Type = "File" },
  @{ Path = Join-Path $ProjectPath ".git"; Description = ".git (repositório)"; Type = "Directory" },
  @{ Path = Join-Path $ProjectPath ".gitignore"; Description = ".gitignore"; Type = "File" },
  @{ Path = Join-Path $ProjectPath "eslint.config.cjs"; Description = "eslint.config.cjs (config ESLint flat)"; Type = "File" },
  @{ Path = Join-Path $ProjectPath ".husky\pre-commit"; Description = ".husky/pre-commit (hook husky)"; Type = "File" }
)

# Função para verificar cada item
function Check-Item($item) {
  $exists = if ($item.Type -eq "Directory") {
    Test-Path $item.Path -PathType Container
  } else {
    Test-Path $item.Path -PathType Leaf
  }
  [pscustomobject]@{
    Item        = $item.Description
    Status      = if ($exists) { "OK" } else { "FALTA" }
    Path        = $item.Path
    CheckedAt   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  }
}

# Executa todas as verificações
$results = $expectedItems | ForEach-Object { Check-Item $_ }

# Exibe relatório no console
Write-Host "🔍 Verificação da Estrutura do Projeto" -ForegroundColor Cyan
Write-Host "Projeto: $ProjectPath"
Write-Host ("=" * 50)
foreach ($r in $results) {
  $color = if ($r.Status -eq "OK") { "Green" } else { "Red" }
  $icon = if ($r.Status -eq "OK") { "✅" } else { "❌" }
  Write-Host "$icon $($r.Item)" -ForegroundColor $color
}
Write-Host ("=" * 50)
Write-Host "✅ = Presente, ❌ = Ausente" -ForegroundColor Cyan

# Exporta relatório para CSV
try {
  $results | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8
  Write-Host "📄 Relatório salvo em '$ReportFile'" -ForegroundColor Green
} catch {
  Write-Host "❌ Falha ao salvar relatório: $_" -ForegroundColor Red
}


# ---------- exit code for CI ----------
$missing = $results | Where-Object { $_.Status -eq "FALTA" }
if ($missing.Count -gt 0) { exit 3 } else { exit 0 }
