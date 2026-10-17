# config

Local configuration for scripts: tenant name, subscription, certificate thumbprint, paths.

- `lab.example.json` is the committed example with placeholder values.
- Copy it to `lab.json` and fill in your values. `lab.json` is ignored by git and Claude
  Code is not allowed to read it (`.claude/settings.json`).
- Never store passwords or client secrets here. Use certificates in the Windows certificate
  store, a managed identity, or a secret manager.
