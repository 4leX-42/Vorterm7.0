---
paths:
  - "**/*.ps1"
  - "**/*.psm1"
  - "**/*.psd1"
---

# PowerShell script standard (loaded when a script is read or edited)

- Start from `Templates/script-template.ps1`. Keep its header fields.
- `.SYNOPSIS` starts with `READ-ONLY.` or `WRITE (dry-run by default).`
- `.NOTES` states `Context: user | admin | SYSTEM`, the permissions or roles needed and
  the modules required.
- Must run on Windows PowerShell 5.1 and PowerShell 7: no `??`, `?.`, ternary `a ? b : c`,
  `&&` / `||` pipeline chains, `ForEach-Object -Parallel` or `Clean {}` blocks.
- ASCII only in `.ps1` files (no accents or typographic quotes). Windows PowerShell 5.1
  reads BOM-less files as Windows-1252, so non-ASCII characters break strings.
- Everything that varies is a parameter: no hard-coded users, mailboxes, tenants, paths.
- WRITE scripts: `-Execute` switch; without it they only report what they would do. Save
  the current state to `exports/` before changing it and read the result back afterwards.
- Use `-LiteralPath` for file paths that come from users or data.
- No `Invoke-Expression`, no `iex`, no downloading and running remote code.
- If the script touches per-user state (HKCU, profile, Outlook) and may run as SYSTEM
  (remote support tools, Intune), detect it and run that part in the user's session.
- Validate before handing over: `.\Tools\Test-LabScripts.ps1 -Path <file>`.
- Comment only decisions that are not obvious from the code.
