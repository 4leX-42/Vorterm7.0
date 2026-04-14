# TERMIX `v2.1`
> *One script. Full PowerShell environment. Zero manual setup.*

```
config → modules → packages → ready
```

---

## WHAT IT DOES

Ejecuta `INSTALAR.bat` y el sistema se configura solo:

- **Execution Policy** — `RemoteSigned` en `CurrentUser`, fallback a `Process` si hay GPO
- **`$PROFILE` generado** para PS7 y PS5.1 — backup automático del anterior
- **Módulos** — PSReadLine `2.3.6+`, Terminal-Icons, posh-git
- **Paquetes via winget** — Git, Python 3.12, .NET SDK 8, Windows Terminal, JetBrainsMono Nerd Font
- **PS7** — se instala solo si no está presente en el sistema

---

## PROFILE / RUNTIME

Lo que carga cada vez que abres una terminal:

```
PSReadLine     historial incremental · predicción · ListView · atajos ↑↓
posh-git       rama actual en el prompt  (solo si git.exe existe)
Terminal-Icons iconos en ls/dir
```

```
ExchangeOnlineManagement  →  lazy load  (se importa al primer Connect-ExchangeOnline)
Microsoft.Graph           →  lazy load  (se importa al primer Connect-MgGraph)
```

> Los módulos pesados no bloquean el arranque.

**Prompt:**
```
[22:47] C:\proyectos  [main] >
```

---

## DEPLOY

```bat
INSTALAR.bat          # doble clic — se auto-eleva si necesita admin
```

```powershell
.\setup_terminal.ps1 -StartPath "C:\dev"   # directorio de inicio fijo
.\setup_terminal.ps1 -SkipInstalls         # solo profile + módulos, sin winget
```

---

## POST-INSTALL

Windows Terminal → Configuración → PowerShell → **Línea de comandos**:
```
pwsh -NoLogo -NoProfileLoadTime
```
Windows Terminal → PowerShell → Apariencia → **Fuente**:
```
JetBrainsMono Nerd Font
```

---

## NOTES

- Idempotente — seguro de relanzar, nunca reinstala lo que ya existe
- Backup con timestamp antes de sobreescribir el `$PROFILE`
- Requiere Windows 10/11 · winget · Admin
