# Changelog

## 7.2 - 2026-10-17

### Added
- **LAB CloudOps / Azure** (optional): checkbox, folder picker and unattended `-LabRoot`.
  Separate generator `lab/New-VortermLab.ps1` with a manifest-driven template; validates
  the path, permissions and an existing LAB before writing; never overwrites or deletes.
- **Multi-pane**: `m2` / `m3` / `m4` (`-Rows`, `-Claude`), `close N`, `/commands`, hidden
  "Vorterm Mosaic" profile (black, no background image), shortcuts Ctrl+Shift+3 / B / Z
  added only when those keys are free.
- **Node.js LTS** option (MCP servers for Claude Code).
- Unattended options: `-WorkDir`, `-Node`, `-ClaudeCode`, `-VSCode`, `-NoMultiPane`,
  `-LabRoot`, `-LabAdopt`, `-Reset`; exit code 1 on warnings.
- Install log in `%LOCALAPPDATA%\Vorterm\logs`.
- Tests: `tests/Test-VortermStatic.ps1`, `tests/Test-VortermLab.ps1`,
  `tests/Test-VortermInstall.ps1` (disposable VM only).
- Cross-links with the companion repository Claude Code Setup Guide.

### Changed
- The PowerShell profile is no longer overwritten: Vorterm manages only its block between
  `# >>> vorterm >>>` markers and keeps everything else. 7.0/7.1 profiles are migrated.
- Windows Terminal: only the real PowerShell 7 profile is patched (not every profile that
  mentions pwsh); background and icon are set only when the profile has none; the file is
  written only when something changes.
- Backups: one `.vorterm-original` plus rotating `.vorterm-bak-*` (last 5); user `.bak-*`
  files are never touched.
- PSReadLine is installed only when PowerShell 7 does not already have 2.3.6 or newer
  (no downgrade of the 2.4.x bundled with PowerShell 7.5+).
- Execution policy check reads CurrentUser / LocalMachine / GPO instead of the process
  scope set by INSTALAR.bat.
- Module and profile paths follow OneDrive "Known Folder Move".
- Reset only removes what Vorterm added and always keeps a `.before-reset-*` copy; the
  history option is now off by default.

### Fixed
- Red `Import-Clixml: Root element is missing` when several terminals start together
  (Terminal-Icons rewrites its XML on every import; the import is now serialized).
- Embedded fallback theme had two missing icons; the installer is pure ASCII again.
