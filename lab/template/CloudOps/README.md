# CloudOps

Day-to-day operations: runbooks, monitoring and alerting, recurring tasks and
troubleshooting guides that are not specific to one product area.

| Folder | Contents |
| :-- | :-- |
| `Runbooks/` | Step-by-step procedures from `Templates/runbook.md`. One file per procedure. |
| `Monitoring/` | Alert rules, dashboards, thresholds and the reasoning behind them. |

## Runbooks

| Runbook | When to use it |
| :-- | :-- |
| `Runbooks/EXAMPLE-low-disk-space.md` | A server or VM reports low free disk space (fictitious example) |

## Conventions

- A runbook is done when someone else can follow it without asking you anything.
- Every runbook has a verification step and a rollback section, even if the rollback is
  "not applicable, read-only".
- Pitfalls found while using a runbook are added to it with the date.
