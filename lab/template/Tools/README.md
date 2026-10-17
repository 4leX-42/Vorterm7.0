# Tools

Helpers for the LAB itself. They only read or write files inside the LAB; none of them
connects to any service.

| Script | What it does |
| :-- | :-- |
| `New-LabItem.ps1` | Creates a runbook, change plan, incident, postmortem, investigation, project or handoff from `Templates/` with the date and title filled in. Never overwrites. |
| `Test-LabScripts.ps1` | Checks every script: parses on Windows PowerShell 5.1 and PowerShell 7, ASCII only, header present (READ-ONLY / WRITE, Context), no `Invoke-Expression`. |

```powershell
.\Tools\New-LabItem.ps1 -Type incident -Area Cybersecurity -Title 'Phishing report'
.\Tools\New-LabItem.ps1 -Type project  -Area Azure         -Title 'Backup review'
.\Tools\Test-LabScripts.ps1
.\Tools\Test-LabScripts.ps1 -Path .\Azure\Scripts\My-Script.ps1
```

## Execution policy

If Windows refuses to run the scripts ("running scripts is disabled on this system"),
allow local scripts for your user only:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Files downloaded from the internet (for example a zip) are blocked by RemoteSigned until
you unblock them after reviewing them:

```powershell
Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File
```
