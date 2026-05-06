# Vorterm7.0

Professional terminal installer for Windows. Single double-click.

---

## Use

`INSTALAR.bat` -> GUI opens -> set startup dir -> tick components -> **Execute install**.

No manual Windows Terminal steps. Font, command-line flags, default profile and (optional) elevation are applied automatically.

---

## What it installs

**Apps (winget, parallel):**
- PowerShell 7
- Git
- Windows Terminal
- JetBrainsMono Nerd Font
- oh-my-posh (drives the prompt theme + glyphs)

**PowerShell modules:**
- PSReadLine 2.3.6 (ListView prediction)
- Terminal-Icons (icons in `ls`)
- posh-git

**Configuration (auto):**
- `$PROFILE` for PS7 + PS5.1 (UTF-8 BOM)
- Windows Terminal `settings.json` patched (JSONC-safe parser):
  - PS7 profile `commandline` -> `pwsh.exe -NoLogo -NoProfileLoadTime`
  - Profile + defaults `font.face` -> auto-detected Nerd Font name
  - `startingDirectory` -> chosen path
  - `defaultProfile` -> PowerShell 7 GUID
  - `elevate: true` -> if "Run as Administrator" is ticked
- ExecutionPolicy -> RemoteSigned (CurrentUser)
- Post-install verify: confirms Terminal-Icons loads in PS7 + Nerd Font in registry

---

## Profile (visual / terminal only — no Azure / M365 / EXO)

- Extra PATH: Git, Node, Vim, GnuWin32 (when present)
- **oh-my-posh** prompt with `amro.omp.json` theme. Falls back to a minimal built-in prompt if oh-my-posh missing.
- **posh-git** — git status segments
- **Terminal-Icons** — glyphs in `ls`/`gci`
- **PSReadLine 2.3.6** — `HistoryAndPlugin` predictions, `ListView` view, full key handlers (Ctrl+arrows, Ctrl+Backspace/Delete, Home/End)
- Aliases: `ll`, `g`, `grep` (Select-String), `which` (Get-Command), `touch` (New-Item), `profile` (Open-Profile)
- Functions: `Open-Profile`, `SysInfo`, `Update-Modules`, `html <file|url>`, `open <path>`, `serve [-Port 8000] [-Path .]`, `sudo <cmd>`

---

## Performance

- All winget installs run in parallel. End-to-end install on a clean box is ~2-4x faster than serial.
- Skips the slow `winget list` pre-check; relies on idempotent `winget install`.
- Async worker runspace -> UI never freezes.

---

## Idempotency / safety

- Re-run is safe. Modules and packages skip if already installed.
- Backups before overwrite: `*.bak-<timestamp>` for `$PROFILE` and Windows Terminal `settings.json`.
- Each component has its own checkbox -> uncheck to skip.

---

## Reset / clean (deep)

`Reset terminal` button does a **deep** reset across all common Windows 11 user-level terminal customisations, regardless of whether TERMIX put them there. Useful when a user already has some other config and wants to lay TERMIX (or anything else) on top.

Per-checkbox actions:

- **Reset all PowerShell profiles (PS5.1 + PS7, all hosts)**
  Scans `Documents\PowerShell` and `Documents\WindowsPowerShell` for `profile.ps1`, `Microsoft.PowerShell_profile.ps1`, `Microsoft.PowerShellISE_profile.ps1`, `Microsoft.VSCode_profile.ps1`. Restores the latest `*.bak-<timestamp>` if present; otherwise saves a `*.before-reset-<stamp>` safety copy and deletes.

- **Clear PSReadLine history**
  Wipes every `*_history.txt` in `%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine` (Console / ISE / VSCode hosts).

- **Uninstall terminal/prompt modules** (allowlist; cloud/dev tools never touched)
  `Uninstall-Module -AllVersions` for: `PSReadLine`, `Terminal-Icons`, `posh-git`, `oh-my-posh`, `PowerLine`, `PSColor`, `Get-ChildItemColor`, `Pansies`, `PoshColor`, `PSFzf`, `PSEverything`, `cd-extras`, `z`, `PowerShellHumanizer`, `BurntToast`, `DockerCompletion`, `WslInterop`. Falls back to direct `Remove-Item` of the user `ModuleBase` if `Uninstall-Module` fails. Also runs `winget uninstall JanDeDobbeleer.OhMyPosh` if that package is present.

  **Never uninstalled** (explicit blocklist): `Az.*`, `AzureAD`, `AzureRM`, `Microsoft.Graph.*`, `MSOnline`, `ExchangeOnlineManagement`, `MicrosoftTeams`, `PnP.*`, `SharePoint*`, `Microsoft.PowerShell.*` (core), `PowerShellGet`, `PackageManagement`, `Pester`, `PSScriptAnalyzer`, `SqlServer`, `dbatools`.

- **Reset Windows Terminal settings.json**
  Restores the latest TERMIX backup if present. Otherwise opens the file (JSONC-aware), and removes only the TERMIX-set keys from the PS7 profile (`commandline` matching the TERMIX signature, `font`, `elevate`, `startingDirectory`) plus `defaults.font` if it points to a Nerd Font. Color schemes, keybindings, themes and other profiles are preserved.

A confirmation dialog lists every action before anything runs. **Never uninstalled by Reset**: PowerShell 7, Git, Windows Terminal app, Nerd Font. Remove those manually with `winget uninstall --id <package-id>` if needed.
