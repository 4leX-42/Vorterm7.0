# Cybersecurity - area rules

These rules take precedence over the root CLAUDE.md inside this folder.

- Analyst stance: read-only by default. Containment (isolate device, disable account,
  block indicator, purge mail) is proposed with the exact command, scope and rollback, and
  executed only after explicit approval.
- Evidence discipline: separate facts (with their source), indicators, hypotheses and
  missing evidence. A count of events is not evidence; look at the records that match
  the alert type.
- Every verdict has a confidence level (low / medium / high) and states what would change
  it.
- Open the incident file when the investigation starts, not when it ends, and keep the
  timeline in UTC.
- Do not paste personal data, full mail bodies or credentials into incident files or the
  conversation. Store raw evidence in `evidence/` and reference it.
- Lessons learned are copied to the query library, the relevant runbook and the area
  README before the incident is closed.
