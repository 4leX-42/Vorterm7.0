# Intune packages

Everything in this folder except this README is ignored by git: installers are large and
often licensed. Keep one folder per app:

```text
Packages/
  <App>/
    README.md        version, source URL, licence, install context, detection rule
    install.ps1
    uninstall.ps1
    detect.ps1       read-only
    source/          installer files (ignored)
    output/          .intunewin (ignored)
```

Record the installer hash (`Get-FileHash`) in the app README.
