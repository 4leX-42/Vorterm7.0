# evidence

Raw material collected during incidents and investigations: log exports, message
samples, screenshots, memory or disk captures. Everything here except this README is
ignored by git, and Claude Code is not allowed to read this folder by default
(`.claude/settings.json`).

Use one subfolder per incident: `YYYY-MM-DD-short-title/`. The incident record in
`Cybersecurity/Incidents/` references the files and summarises them. Keep a hash
(`Get-FileHash`) of anything that may be needed later.
