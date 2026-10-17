# LAB - instructions for Claude Code

This folder is an IT operations lab: Azure, Microsoft 365, Exchange, Intune,
security operations, automation and documentation. These rules apply to every session
started here. A `CLAUDE.md` inside an area adds rules for that area only; when the two
disagree, the area file wins inside its folder.

Replace the placeholders in "Environment" once; keep the rest generic.

## Environment (fill in)

- Organisation / tenant: `<name>` (never paste tenant or subscription IDs here; put them in
  `config/lab.json`, which git ignores)
- Primary shell: PowerShell 7 (`pwsh`); scripts must also run on Windows PowerShell 5.1
- How we authenticate for automation: `<interactive admin | certificate app-only | managed identity>`
- Change approval: `<who approves what>`

## Continue here first

Before starting new work, open the `TODO.md` of the area or project you are asked about
(and the root `TODO.md`). They say where the last session stopped, what is blocked on a
person and what the next step is. Update them before you finish.

## Mandatory workflow for anything that changes a system

1. **Check the real state** with cheap read-only queries (identity, scope, counts,
   licences, holds, existing objects). Do not plan from assumptions.
2. **Write a plan block** in the reply (or `Templates/change-plan.md` for bigger changes):
   - **What**: commands or script, module and cmdlets
   - **Scope**: explicit list, or criterion plus count
   - **Risks**: side effects, and which steps are irreversible
   - **Rollback**: exact steps to undo
3. **Dry run**: run the script without `-Execute` and show the output.
4. **Execute** only after approval. The approval covers the plan as written; anything new
   or bigger means stop and re-plan.
5. **Verify** by reading the result back and checking the numbers
   (before - removed + added = after).
6. **Record**: transcript in `logs/`, snapshot or export in `exports/`, and update the
   runbook, incident file or TODO.

Read-only work (queries, reports, reviews) does not need a plan or approval.

## Rules for sensitive operations

- Prefer reversible actions: disable before delete, move before purge, remove an
  assignment before removing the object. Call out anything irreversible in the plan.
- In a production tenant, test with **new** objects you create (unique names with a
  timestamp). Never modify or delete existing objects that you did not create in this
  session, even if they look like test objects.
- Save the current state (CSV/JSON in `exports/`) before changing it.
- Least privilege: request only the scopes and roles the task needs; no standing admin.
- No hidden code: no `Invoke-Expression` on built strings, no downloaded scripts piped
  into a shell. Keep reviewable `.ps1` files.
- A secret that appears in the conversation cannot be taken back, only rotated. Never
  print, copy or read secret files (`config/`, `*.pfx`, `*.pem`, `.env`, token caches).

## Scripts

The script standard lives in `.claude/rules/powershell-scripts.md` and loads automatically
whenever a `.ps1` file is read or edited. In short: start from
`Templates/script-template.ps1`, Windows PowerShell 5.1 compatible, ASCII only,
parameterised, dry-run by default with `-Execute`, header says READ-ONLY or WRITE and the
execution context (user, admin, SYSTEM). Before writing a new script, search the LAB for
one that already does it and extend it instead (skill: `/new-script`).

## Data separation

| Kind | Where | In git |
| :-- | :-- | :-- |
| Code (scripts, modules, IaC, queries) | area folders | yes |
| Documentation, runbooks, decisions | area folders, `Documentation/` | yes |
| Configuration with real values | `config/*.json` | no (only `*.example.*`) |
| Exports, reports with real data | `exports/` | no |
| Transcripts and logs | `logs/` | no |
| Evidence collected during incidents | `evidence/` | no |

Documents link to the file path and give a summary; they never embed a raw dump of real
data (names, mailboxes, IP addresses, device IDs).

## Naming

- Scripts: `Verb-Noun.ps1` with approved PowerShell verbs (`Get-`, `Set-`, `New-`,
  `Remove-`, `Test-`, `Repair-`...). Examples start with `EXAMPLE-`.
- Dated documents: `YYYY-MM-DD-short-title.md` (incidents, reports, handoffs).
- Decisions: `Documentation/Decisions/NNNN-short-title.md`.
- Exports and logs: `<topic>-YYYYMMDD-HHMM.<ext>`.

## How to answer

- Put the important data in the reply (tables with full values). The user may not see
  tool output.
- Large results go to a CSV in `exports/` plus a short summary in the reply.
- Investigations separate facts, hypotheses, missing evidence and conclusion, and give a
  confidence level plus "what would change this verdict".
- Say plainly what was not checked or could not be verified.

## Tools available here

- `Tools/New-LabItem.ps1`: creates a runbook, incident, change plan, investigation,
  handoff or project from `Templates/`.
- `Tools/Test-LabScripts.ps1`: syntax (PowerShell 5.1 and 7), ASCII and header checks.
  Run it before committing scripts.
- Subagents in `.claude/agents/`: `readonly-auditor`, `script-reviewer`.
- Skills in `.claude/skills/`: `new-script`, `change-plan`, `incident`.

Plugins and MCP servers are optional. Use them when they are available in the session and
fall back to scripts and CLIs when they are not. See `LAB-INVENTORY.md`.
