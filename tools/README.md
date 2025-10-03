# Tools (scripts auxiliares)

Coleção de scripts PowerShell que agilizam o fluxo de trabalho do repositório.

> **Requisitos:** Windows PowerShell 5+ ou PowerShell 7+, Git instalado.  
> **Se der "script is not digitally signed"**:  
> `Set-ExecutionPolicy -Scope Process Bypass -Force` e `Unblock-File .\tools\<script>.ps1`

---

## Sumário

- `checkpoint.ps1` — **typecheck + vitest (resumo) + git status** para verificar rápido antes de commits/push.
- `push.ps1` — **stage/commit/typecheck/push** (e imprime checkpoint).
- `tag.ps1` — cria **tags de checkpoint** (idempotente) e faz **push** opcional.
- `ci-rerun.ps1` — cria **commit vazio** para **re-rodar o GitHub Actions** (flags para pular hooks/push).

---

## Scripts e uso

### 1) `checkpoint.ps1`
Mostra:
- Timestamp, branch e último commit
- Resumo de **typecheck (app+tests)**
- **Vitest** com reporter do `vitest.config.ts`
- `git status --short`

**Uso**
```powershell
.\tools\checkpoint.ps1
```

### 2) `push.ps1`
Faz stage, commit, typecheck e push em sequência.

**Uso**
```powershell
.\tools\push.ps1 -Message "feat: descrição do commit"
```

### 3) `tag.ps1`
Cria tags de checkpoint com timestamp automático ou nome customizado.

**Uso**
```powershell
# Com timestamp automático
.\tools\tag.ps1 -Message "checkpoint: auth fix + tests types"

# Com nome específico
.\tools\tag.ps1 -Name "checkpoint-pos-vitest" -Message "vitest"

# Apenas local (sem push)
.\tools\tag.ps1 -Message "checkpoint local" -NoPush
```

### 4) `ci-rerun.ps1`
Cria commit vazio para re-executar GitHub Actions.

**Uso**
```powershell
# Padrão (com hooks e push)
.\tools\ci-rerun.ps1

# Com mensagem customizada
.\tools\ci-rerun.ps1 -Message "ci: re-run após ajustes no clients"

# Pula hooks locais
.\tools\ci-rerun.ps1 -NoVerify

# Só commit local (sem push)
.\tools\ci-rerun.ps1 -NoPush
```
