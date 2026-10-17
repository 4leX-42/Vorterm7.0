# PowerShell - area rules

- Modules export only public functions (`Export-ModuleMember` or `FunctionsToExport` in
  the manifest); helpers stay private.
- A function used by two or more scripts moves into a module here instead of being copied.
- Changing a shared function: search every caller in the LAB (`Grep` the function name)
  and list them in the reply, because the change affects all of them.
- Tests: add or update a Pester test in `Tests/` when changing a module. Tests must not
  touch real tenants; mock the cloud cmdlets.
