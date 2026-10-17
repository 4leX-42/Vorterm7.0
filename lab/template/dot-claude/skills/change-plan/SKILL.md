---
name: change-plan
description: Prepare a change plan (what, scope, risks, rollback, verification) before modifying Azure, Microsoft 365, Exchange, Intune or any production system. Use before any write operation that is not trivial.
argument-hint: "[change to plan]"
---

Prepare a change plan for: $ARGUMENTS

1. **Current state.** Run read-only checks (or ask the `readonly-auditor` subagent) to
   establish scope and counts. Write down the exact queries used.
2. **Fill in the plan** with `Templates/change-plan.md`. For a small change, put the same
   sections in the reply; for anything with more than a handful of objects, create the
   file with `.\Tools\New-LabItem.ps1 -Type change -Area <Area> -Title '<title>'`.
3. **Be explicit about**:
   - scope as a list or as a filter plus count;
   - irreversible steps (and a reversible alternative if one exists);
   - rollback steps that can actually be executed;
   - the snapshot that will be taken before the change (`exports/...`);
   - how success will be verified (numbers, read-back query).
4. **Dry run** the script or command and paste the relevant output into the plan.
5. Stop and ask for approval. Approval covers exactly this plan; anything else needs a
   new plan.
