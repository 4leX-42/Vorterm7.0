# Intune

Devices, compliance, configuration profiles, applications and Autopilot.

| Folder | Contents |
| :-- | :-- |
| `Scripts/` | Graph (DeviceManagement) scripts, remediation and detection scripts, platform scripts. |
| `Policies/` | Exported policy JSON (sanitised) and notes per policy: purpose, assignment, rollback. |
| `Packages/` | Win32 app sources and `.intunewin` outputs. Ignored by git except its README. |

## Scripts

| Script | What it does | Type |
| :-- | :-- | :-- |
| - | Add a row per script | - |

## Conventions

- One folder per app under `Packages/<App>/` with install, uninstall and detection
  scripts; the README of the app says the install context (system or user).
- Detection scripts must be read-only and fast.
- Test installers in a disposable virtual machine with snapshots, never on your own PC.
