# Cybersecurity

Incident response, threat hunting, detection notes, hardening baselines and vulnerability
management.

| Folder | Contents |
| :-- | :-- |
| `Incidents/` | One file per incident: `YYYY-MM-DD-short-title.md`, from `Templates/incident.md`. |
| `Queries/` | Reusable KQL / hunting queries with a header (purpose, tables, parameters). |
| `Hardening/` | Baselines and their exceptions, with the reason and owner of each exception. |

Raw evidence (exports, mail samples, logs) goes to `evidence/` at the LAB root, which git
ignores. Incident files reference the path and summarise.

## Index

| Date | Incident | Status | Verdict |
| :-- | :-- | :-- | :-- |
| 2026-01-15 | `Incidents/EXAMPLE-2026-01-15-suspicious-sign-in.md` (fictitious) | closed | benign |
