# Outlook / Exchange - area rules

- Mailbox and folder permissions: report current permissions (including inherited and
  group-based) before adding or removing any.
- Prefer reversible actions: move instead of purge, disable a rule instead of deleting it,
  convert a mailbox instead of removing it. Purging items or removing mailboxes is
  irreversible once retention ends.
- Mail flow (transport) rules affect every message: test with a single sender or with
  "audit only" first and include the exact conditions in the plan.
- Client fixes that touch the user profile or HKCU must run in the user's session, not as
  SYSTEM. Say which context the script needs.
