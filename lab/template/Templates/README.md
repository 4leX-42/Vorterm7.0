# Templates

Starting points for recurring documents and code. Create items with
`..\Tools\New-LabItem.ps1`, which copies the template, fills in the date and title and puts
the file in the right folder.

| Template | `-Type` | Created in |
| :-- | :-- | :-- |
| `runbook.md` | `runbook` | `<Area>/Runbooks/` (CloudOps by default) |
| `change-plan.md` | `change` | `<Area>/Changes/YYYY-MM-DD-title.md` |
| `incident.md` | `incident` | `Cybersecurity/Incidents/` or `<Area>/Incidents/` |
| `postmortem.md` | `postmortem` | `Documentation/Reports/` |
| `investigation-notes.md` | `investigation` | `<Area>/Investigations/` |
| `project-brief.md` | `project` | `<Area>/Projects/YYYY-MM-DD-title/README.md` + `TODO.md` |
| `context-handoff.md` | `handoff` | root of the LAB or the project folder |
| `script-template.ps1` | - | copy by hand (or `/new-script` in Claude Code) |
| `query-template.kql` | - | copy by hand into `Cybersecurity/Queries/` |

Edit the templates freely: they are yours. Keep the section names stable if you rely on
Claude Code skills that refer to them.
