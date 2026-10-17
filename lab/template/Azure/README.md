# Azure

Subscriptions, resource groups, compute, storage, networking, workload identities,
policy and cost.

| Folder | Contents |
| :-- | :-- |
| `Scripts/` | PowerShell (Az module) or Azure CLI scripts. One task per script. |
| `IaC/` | Bicep or Terraform. One subfolder per deployment, each with its own README. |

Architecture diagrams and design notes go to `Documentation/`.

## Scripts

| Script | What it does | Type |
| :-- | :-- | :-- |
| `Scripts/EXAMPLE-Get-AzResourceSummary.ps1` | Counts resources per type and location in the current subscription | READ-ONLY |

## Conventions

- Tag everything you create in a lab subscription (`owner`, `purpose`, `expires`).
- Resource names in examples use the `contoso` prefix; replace them, never commit real IDs.
- Cost: note the expected monthly cost in the change plan of anything you deploy.
