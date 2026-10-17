---
name: new-script
description: Create a new PowerShell script in the lab following the script standard (template header, PS 5.1 compatible, ASCII, dry-run by default). Use when the user asks for a new script or automation.
argument-hint: "[area] [what the script should do]"
---

Create a new lab script for: $ARGUMENTS

1. **Look for duplicates first.** Search the lab (`Glob **/*.ps1`, `Grep` for the main
   cmdlets) for a script that already does this. If one exists, propose extending it.
2. **Pick the place.** `<Area>/Scripts/Verb-Noun.ps1` with an approved verb. Generic
   helpers go to `PowerShell/Scripts/`.
3. **Start from `Templates/script-template.ps1`.** Fill in every header field:
   READ-ONLY or WRITE, Context (user/admin/SYSTEM), permissions, modules.
4. **Write it** following `.claude/rules/powershell-scripts.md`. WRITE scripts get
   `-Execute`, a pre-change snapshot to `exports/` and a read-back check.
5. **Validate**: run `.\Tools\Test-LabScripts.ps1 -Path <file>` and fix every finding.
6. **Review**: ask the `script-reviewer` subagent to review the file; fix BLOCKING items.
7. **Document**: add a row to the area `README.md` script table (name, what it does,
   READ-ONLY/WRITE).
8. Reply with: path, how to run it (dry run first), what it needs, and the rollback for
   WRITE scripts. Do not run a WRITE script with `-Execute` without an approved plan.
