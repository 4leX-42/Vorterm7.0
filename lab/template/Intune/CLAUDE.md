# Intune - area rules

- Assign new or changed policies and apps to a pilot group first; widen the assignment in
  a separate, planned step.
- Export the current policy or app JSON to `exports/` before editing it; that export is
  the rollback.
- State whether an assignment targets devices or users; it changes who is affected.
- Remediation and platform scripts run as SYSTEM by default. Anything that touches the
  user profile must say so and handle the SYSTEM context.
- Wipe, retire, delete device and Autopilot deregistration are irreversible: never include
  them in a bulk operation without an explicit list of devices in the plan.
- Installers are tested in a virtual machine, never on the operator's workstation.
