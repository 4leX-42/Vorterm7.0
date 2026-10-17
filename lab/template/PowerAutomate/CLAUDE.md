# Power Automate - area rules

- Export the current flow definition (solution export or `pac` CLI) to `exports/` before
  editing it; that export is the rollback.
- Exported definitions committed to `Flows/` are sanitised: no connection references with
  real account names, no secrets in HTTP actions, no tenant-specific IDs.
- State the run-as identity and the connections a flow uses; changing them changes what
  the flow can access.
- Flows that send mail or post messages are tested against a test recipient first.
- Disabling a flow is the reversible option; deleting it loses run history.
