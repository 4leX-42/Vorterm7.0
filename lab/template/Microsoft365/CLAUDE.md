# Microsoft 365 - area rules

- Connect-MgGraph with explicit `-Scopes`; never request `Directory.ReadWrite.All` or
  similar broad scopes when a narrower one works. Read-only work uses `*.Read.All` scopes.
- Before changing users, groups or licences: show the list or the filter plus the count,
  and save the current state (members, licences, attributes) to `exports/`.
- Licence changes: check available units first; removing a licence can start a data
  retention countdown for mailbox and OneDrive. Say so in the plan.
- Deleted users and groups go to the recycle bin for a limited time; hard delete is
  irreversible. Prefer disabling sign-in over deleting.
- Conditional access and role assignments are security changes: test with report-only
  mode or a pilot group first, and always keep a break-glass account excluded.
