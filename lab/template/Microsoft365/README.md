# Microsoft 365

Entra ID (users, groups, roles, app registrations, conditional access), licensing,
SharePoint, Teams and Microsoft Graph automation. Exchange and Outlook live in `Outlook/`.

| Folder | Contents |
| :-- | :-- |
| `Scripts/` | Microsoft Graph PowerShell SDK scripts (users, groups, licences, Teams, SharePoint). |
| `EntraID/` | Notes and exported (sanitised) configuration: conditional access, roles, app registrations. |

## Scripts

| Script | What it does | Type |
| :-- | :-- | :-- |
| - | Add a row per script | - |

## Conventions

- Connect with the smallest Graph scopes the task needs and list them in the script header.
- Group membership questions: say whether the answer is direct or transitive.
- Exported configuration (`EntraID/`) is sanitised: no tenant IDs, no object IDs of real
  users, no secrets of app registrations.
