# Lab

An optional working folder that Vorterm can create for IT, cloud operations, DevOps and security
work. It reproduces a way of working with Claude Code (plan, dry run, verify, record) in a
generic form: no company data, no tenant identifiers, no credentials.

## Create it

- **From the installer**: tick *lab*, choose the parent folder (default:
  Documents) and press INSTALL. The LAB is created as `<folder>\LAB`.
- **Unattended**: `setup_terminal.ps1 -NoGui -LabRoot "D:\Work"`.
- **On its own**, without installing anything else:

  ```powershell
  .\lab\New-VortermLab.ps1 -Root "$env:USERPROFILE\Desktop"
  .\lab\New-VortermLab.ps1 -Root 'D:\Work' -DryRun        # show what would be created
  .\lab\New-VortermLab.ps1 -Root 'D:\Work' -ValidateOnly  # only check path and permissions
  ```

It needs no administrator rights, no internet, no Azure or Microsoft 365 account, and it
never signs in or connects anywhere. Size: under 1 MB.

## What it contains

```text
LAB/
  README.md  CLAUDE.md  TODO.md  LAB-INVENTORY.md  .gitignore  .gitattributes
  .mcp.json.example           optional read-only Azure MCP server (not enabled)
  .claude/                    settings (secrets unreadable, risky commands ask first),
                              agents (readonly-auditor, script-reviewer),
                              skills (new-script, change-plan, incident),
                              rules/powershell-scripts.md (script standard)
  Azure/  Microsoft365/  Outlook/  Intune/  Cybersecurity/  PowerAutomate/
  CloudOps/  PowerShell/  DevOps/  Documentation/
  Templates/                  runbook, change plan, incident, postmortem, investigation,
                              project, handoff, script template, KQL template
  Tools/                      New-LabItem.ps1, Test-LabScripts.ps1
  config/  exports/  logs/  evidence/   local data, ignored by git
```

Every area has a README; areas with their own risks (Azure, Microsoft 365, Outlook,
Intune, Cybersecurity, Power Automate, PowerShell) have a short `CLAUDE.md` that only adds
what the root file does not say. Files named `EXAMPLE-*` are fictitious and can be deleted.

## Safety rules of the generator

| Situation | Behaviour |
| :-- | :-- |
| `<folder>\LAB` does not exist | Created |
| `LAB` exists and was created by Vorterm (`.vorterm-lab.json`) | Update: missing files added, files you never edited refreshed to the new template, files you edited kept and listed as "kept" |
| `LAB` exists, is empty | Used |
| `LAB` exists with other content | Conflict, nothing written. `-Adopt` (or "Yes" in the installer) adds only missing files |
| Folder missing, not writable, a file, a system folder, too long | Rejected with a clear message before anything is written |

Nothing is ever deleted, and Reset in Vorterm never touches the LAB.

## Keep it up to date

Run the generator (or the installer with the LAB option) again with the same parent
folder. `.vorterm-lab.json` stores the template version and the hash of every file as
Vorterm wrote it; that is how the generator knows which files you have not changed. Keep
it, and commit it if the LAB is a git repository.

To see what a newer template would change in a file you edited, compare it with
`lab\template\<path>` in the Vorterm folder.

## Use it with Claude Code

Open Claude Code in the LAB folder. `CLAUDE.md` loads automatically; area files load when
Claude works in that folder; the script standard loads when a `.ps1` file is touched.
Optional plugins and MCP servers are listed in `LAB-INVENTORY.md`. The Claude Code Setup
Guide (companion repository) configures Claude Code itself.

## Maintainers

- Template files live in `lab/template/`. Names starting with `dot-` become dotfiles
  (`dot-gitignore` -> `.gitignore`), so the template does not act as a git or Claude Code
  folder inside this repository.
- Folders that start empty are listed in `lab/lab-manifest.json`. Bump `version` there
  whenever the template changes.
- Tests: `tests\Test-VortermLab.ps1` (functional, runs in a temporary folder) and
  `tests\Test-VortermStatic.ps1`.
