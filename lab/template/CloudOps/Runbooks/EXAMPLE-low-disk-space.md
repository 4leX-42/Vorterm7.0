# EXAMPLE - Runbook: low free disk space on a Windows server

> Fictitious example of the runbook format. Server names are invented.

| Field | Value |
| :-- | :-- |
| Owner | ops-team@contoso.example |
| Last reviewed | 2026-01-10 |
| Risk | low (read-only checks, cleanup only of known temporary paths) |

## When to use it

Monitoring reports less than 10 % free space on a system or data volume of a Windows
server (for example `SRV-APP01`).

## Prerequisites

- Admin rights on the server (remote PowerShell or console).
- Change window not required for steps 1-3; step 4 needs a change plan.

## Steps

1. **Measure (read-only).**
   ```powershell
   Get-Volume | Select-Object DriveLetter, FileSystemLabel,
       @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}},
       @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}
   ```
2. **Find the biggest folders (read-only).** Use your preferred tool or
   `Get-ChildItem -Directory | ForEach-Object { ... Measure-Object -Sum Length }`.
3. **Clean known temporary locations** (safe, reversible only by restore):
   Windows Update cache via Disk Cleanup, application temp folders listed in the
   application runbook. Never delete from user profiles or application data folders.
4. **Grow the disk** if cleanup is not enough: needs a change plan
   (`Templates/change-plan.md`).

## Verification

Free space above 20 % and the alert cleared in monitoring.

## Rollback

Steps 1-2 are read-only. Step 3 removes temporary files only. Step 4: see its change plan.

## Known pitfalls

- 2026-01-10: Disk Cleanup "Windows Update Cleanup" can take more than 30 minutes; do not
  cancel it.
