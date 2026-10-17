# Change plan: {{TITLE}}

| Field | Value |
| :-- | :-- |
| Date | {{DATE}} |
| Requested by | |
| Approved by | |
| Status | draft / approved / done / rolled back |

## What

Systems, module and cmdlets or script (with parameters) that will run.

## Current state

Read-only queries used and their result (counts, current values). Snapshot saved to
`exports/<topic>-YYYYMMDD-HHMM.csv`.

## Scope

Explicit list of objects, or the filter plus the count it returns today.

## Risks

- Side effects (who notices, what stops working during the change).
- **Irreversible steps**: list them, and the reversible alternative if there is one.

## Dry run

Output of the script without `-Execute` (relevant part).

## Execution

Exact command(s) with `-Execute`. Planned time window.

## Verification

Read-back query and the expected numbers (before - removed + added = after).

## Rollback

Exact steps, using the snapshot above where needed. Tested? yes / no.

## Result

What happened, links to transcript in `logs/`, follow-up items.
