# lab/

Generator and template of the optional **LAB CloudOps / Azure** folder.

| Path | Role |
| :-- | :-- |
| `New-VortermLab.ps1` | Generator. Used by the installer, also runnable on its own |
| `lab-manifest.json` | Template version and folders that start empty |
| `template/` | Files copied into `<folder>\LAB`; `dot-*` names become dotfiles |

```powershell
.\New-VortermLab.ps1 -Root "$env:USERPROFILE\Desktop"            # create or update
.\New-VortermLab.ps1 -Root 'D:\Work' -DryRun                       # preview
.\New-VortermLab.ps1 -Root 'D:\Work' -Adopt                        # existing non-Vorterm LAB folder
.\New-VortermLab.ps1 -Root 'D:\Work' -ValidateOnly -PassThru       # checks only, returns an object
```

Exit codes: 0 ok, 1 invalid path or no permission, 2 conflict, 3 finished with errors.
Full documentation: [../docs/LAB.md](../docs/LAB.md).
