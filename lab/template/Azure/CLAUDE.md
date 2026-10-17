# Azure - area rules

- Reads are free: `az ... list|show`, `Get-Az*`, Resource Graph queries.
- Changes go through a script in `Scripts/` or through IaC in `IaC/`, never as ad-hoc
  one-liners. IaC changes always run `what-if` (Bicep) or `plan` (Terraform) first and the
  output goes into the change plan.
- Never run `terraform apply`, `az deployment ... create` or `New-Az*` / `Remove-Az*`
  against a subscription that is not named in the change plan. Confirm the active
  subscription (`az account show` / `Get-AzContext`) in the same command block as the change.
- Role assignments, policy assignments, network security rules and key vault access are
  security changes: include who gains or loses access in the plan.
- Deleting a resource group is irreversible for most resources. Check locks, backups and
  soft-delete settings first and say so in the plan.
