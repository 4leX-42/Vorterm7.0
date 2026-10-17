# LAB inventory

What exists in this LAB and which optional tools fit it. Nothing in the "optional" lists is
required; the LAB works with plain PowerShell and a text editor.

## Areas

| Area | README | Area rules (CLAUDE.md) | Starts with |
| :-- | :-: | :-: | :-- |
| Azure | yes | yes | `Scripts/`, `IaC/`, read-only example script |
| Microsoft365 | yes | yes | `Scripts/`, `EntraID/` |
| Outlook | yes | yes | `Scripts/`, `Troubleshooting/` |
| Intune | yes | yes | `Scripts/`, `Policies/`, `Packages/` (ignored) |
| Cybersecurity | yes | yes | `Incidents/`, `Queries/`, `Hardening/`, fictitious incident and query |
| PowerAutomate | yes | yes | `Flows/` |
| CloudOps | yes | no | `Runbooks/`, `Monitoring/`, example runbook |
| PowerShell | yes | yes (script standard) | `Modules/`, `Scripts/`, `Tests/`, safe local inventory script |
| DevOps | yes | no | `Pipelines/` |
| Documentation | yes | no | `Decisions/`, `Procedures/`, `Reports/`, example decision record |
| Templates | yes | - | 9 templates |
| Tools | yes | - | `New-LabItem.ps1`, `Test-LabScripts.ps1` |

## Optional tools by area

Install only what you use. Versions move; pin them in your own notes once chosen.

| Area | Tool | Used for |
| :-- | :-- | :-- |
| all | Git | History, review, rollback of documentation and scripts |
| all | PowerShell 7 | Primary shell; scripts must still run on 5.1 |
| all | Visual Studio Code | Editing, Markdown preview, PowerShell extension |
| Azure | Azure CLI (`az`), Az PowerShell module | Read and change Azure resources |
| Azure | Bicep or Terraform | Infrastructure as code with `what-if` / `plan` |
| Microsoft365 | Microsoft.Graph PowerShell SDK | Users, groups, licences, Entra ID |
| Outlook | ExchangeOnlineManagement module | Mailboxes, permissions, mail flow |
| Intune | Microsoft.Graph (DeviceManagement), IntuneWinAppUtil | Policies, apps, packaging |
| Cybersecurity | Defender XDR / Sentinel portals, KQL | Hunting and incident response |
| PowerAutomate | Power Platform CLI (`pac`) | Export and import flow definitions |
| PowerShell | PSScriptAnalyzer, Pester | Lint and tests |

## Optional Claude Code integrations

| Integration | How to enable | Notes |
| :-- | :-- | :-- |
| Read-only Azure MCP server | Copy `.mcp.json.example` to `.mcp.json`, approve it when Claude Code asks (or `/mcp`) | Requires Node.js and an existing `az` / Az sign-in; it never signs in for you. The version is pinned on purpose: check the current release and change it deliberately, never `@latest`. `.mcp.json` is git-ignored so each person opts in. |
| Microsoft Learn docs (plugin or MCP) | Install from your plugin marketplace | Official documentation lookups |
| Security review / static analysis plugins | Install from your plugin marketplace | Review before trusting third-party plugins |
| Status line, hooks, extra skills | Your own `~/.claude` setup | See the Claude Code Setup Guide that complements Vorterm |

A plugin or MCP server that can **write** to a tenant should not be enabled in this LAB by
default. If a plugin brings its own write-capable MCP server, add it to `permissions.deny`
in `.claude/settings.json` and use a read-only server instead.
