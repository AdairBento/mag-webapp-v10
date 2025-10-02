# Tools (scripts auxiliares)

Coleção de scripts PowerShell que agilizam o fluxo de trabalho do repositório.

> **Requisitos:** Windows PowerShell 5+ ou PowerShell 7+, Git instalado.  
> **Se der “script is not digitally signed”**:  
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
