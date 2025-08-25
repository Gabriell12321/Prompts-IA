<#
.SYNOPSIS
  Script seguro para commitar e enviar alterações do projeto RNC para o GitHub.

.DESCRIPTION
  Executa checagens de segurança (busca por secrets), valida tipos de arquivos, faz git pull --rebase,
  commita com mensagem fornecida e faz push para origin main.

.USAGE
  .\rnc_auto_push.ps1 -Message "Breve descrição das alterações"

PARAMETER Message
  Mensagem de commit (obrigatória). Deve ser curta e descritiva. Será prefixada com "rnc: ".

NOTES
  - Não usa force push.
  - Se detectar segredos, interrompe sem commitar.
  - Em caso de conflitos durante rebase, interrompe e informa como proceder.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Message
)

Set-StrictMode -Version Latest
Push-Location -LiteralPath (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)
Try {
    $repoRoot = Resolve-Path -LiteralPath ".." | Select-Object -ExpandProperty Path
    Set-Location -LiteralPath $repoRoot
} Catch {
    Write-Error "Não foi possível determinar o diretório do repositório. Execute o script a partir da pasta 'scripts/'."
    Exit 2
}

Write-Host "RNC auto-push: iniciando checagens..." -ForegroundColor Cyan

# 1) Checagem de segredos simples
$patterns = @('password','passwd','secret','token','api_key','apikey','private_key','id_rsa','\.env')
$found = @()
foreach ($p in $patterns) {
    $matches = Select-String -Path "**\*" -Pattern $p -SimpleMatch -NotMatch:$false -ErrorAction SilentlyContinue | Select-Object Path, LineNumber, Line
    if ($matches) { $found += $matches }
}
if ($found.Count -gt 0) {
    Write-Host "Padrões sensíveis encontrados - abortando commit/push:" -ForegroundColor Red
    $found | Select-Object -First 50 | ForEach-Object { Write-Host "$_" }
    Write-Host "Se esses são falsos positivos, revise manualmente e execute o script novamente." -ForegroundColor Yellow
    Exit 3
}

# 2) Verificar alterações
$status = git status --porcelain
if (-not $status) {
    Write-Host "Nada a commitar." -ForegroundColor Yellow
    Exit 0
}

# 3) Verificar tipos de arquivo alterados
$changedFiles = ($status -split "\n") | ForEach-Object { ($_ -replace '^[ MADRCU?]+','').Trim() } | Where-Object { $_ -ne '' }
$allowedExt = @('.txt','.md','.png','.jpg','.jpeg','.yaml','.yml')
$unexpected = @()
foreach ($f in $changedFiles) {
    $ext = [IO.Path]::GetExtension($f).ToLower()
    if ($ext -and ($allowedExt -notcontains $ext)) { $unexpected += $f }
}
if ($unexpected.Count -gt 0) {
    Write-Host "Arquivos com extensões não esperadas encontrados:" -ForegroundColor Yellow
    $unexpected | ForEach-Object { Write-Host " - $_" }
    Write-Host "Continue apenas se souber que é seguro. O script continuará." -ForegroundColor Yellow
}

Write-Host "Adicionando alterações..." -ForegroundColor Cyan
git add -A

Write-Host "Fazendo pull --rebase de origin/main..." -ForegroundColor Cyan
$pull = git pull --rebase origin main 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pull falhou ou houve conflito; por segurança o processo será interrompido." -ForegroundColor Red
    Write-Host $pull
    Write-Host "Resolva conflitos manualmente e rode: git rebase --continue ou finalize o rebase antes de tentar novamente." -ForegroundColor Yellow
    Exit 4
}

# Fazer commit
$commitMsg = "rnc: $Message"
git commit -m "$commitMsg" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Commit não realizado. Verifique se havia mudanças a commitar ou erros." -ForegroundColor Yellow
    git status --porcelain
    Exit 5
}

Write-Host "Enviando (push) para origin/main..." -ForegroundColor Cyan
$push = git push origin main 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Push falhou." -ForegroundColor Red
    Write-Host $push
    Write-Host "Se for falha de autenticação, configure Git credential manager ou use um PAT." -ForegroundColor Yellow
    Exit 6
}

Write-Host "Push concluído com sucesso." -ForegroundColor Green
Exit 0
