# PowerShell

Shared code used by every area: modules, generic functions and scripts, and their tests.
Product-specific scripts live in their area (`Azure/Scripts`, `Intune/Scripts`...).

| Folder | Contents |
| :-- | :-- |
| `Modules/` | Reusable modules (`<Name>/<Name>.psm1` + `.psd1`). Import with a relative path. |
| `Scripts/` | Generic scripts that are not tied to one product. |
| `Tests/` | Pester tests, named `<Script>.Tests.ps1`. |

## Scripts

| Script | What it does | Type |
| :-- | :-- | :-- |
| `Scripts/Get-LocalInventory.ps1` | Hardware, OS, disks and network summary of the local computer | READ-ONLY |

## Standard

See `.claude/rules/powershell-scripts.md` (the same rules apply to people) and start new
scripts from `Templates/script-template.ps1`. Validate with `..\Tools\Test-LabScripts.ps1`.
