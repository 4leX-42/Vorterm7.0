---
name: incident
description: Open or continue a security or operations incident record and investigate with evidence discipline (facts, hypotheses, confidence). Use when the user reports an alert, a suspicious event or an outage.
argument-hint: "[short description of the incident]"
---

Incident: $ARGUMENTS

1. **Open the record first**, not at the end:
   `.\Tools\New-LabItem.ps1 -Type incident -Area Cybersecurity -Title '<short title>'`
   (use `-Area CloudOps` for outages). If a record for this incident exists, continue it.
2. **Collect read-only evidence.** Queries go to `Cybersecurity/Queries/` when they are
   reusable. Raw exports go to `evidence/` (git-ignored); the record keeps only the path
   and a summary.
3. **Keep the record honest**: facts (with source), indicators, hypotheses, missing
   evidence, timeline. A count is not evidence; look at the records that match the alert.
4. **Verdict** with a confidence level (low / medium / high) and "what would change
   this verdict".
5. **Containment or remediation actions are proposals**: give the exact command, its
   scope and its rollback, and wait for approval. Do not execute them yourself.
6. **Close the loop**: lessons learned go to the relevant runbook, query library or area
   README, and are listed in the record.
