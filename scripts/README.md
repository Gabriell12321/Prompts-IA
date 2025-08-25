# Scripts

Contém utilitários para o fluxo de trabalho RNC.

- `rnc_auto_push.ps1` : script PowerShell para checar, commitar e enviar alterações com regras de segurança.

Uso rápido:

1. Abra PowerShell na pasta `scripts/`.
2. Execute:

```powershell
.\rnc_auto_push.ps1 -Message "Descrição curta do que mudou"
```

O script irá: checar por secrets, validar arquivos, fazer pull --rebase, commitar com prefixo `rnc:` e push para `origin main`.
