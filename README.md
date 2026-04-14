# TERMIX — PowerShell Environment Bootstrapper

Configura un entorno de PowerShell completo en Windows con un solo doble clic. Instala módulos, paquetes y escribe un `$PROFILE` optimizado para arranque rápido.

---

## ¿Qué hace exactamente?

### 1 · Configura el entorno base
- Establece la **Execution Policy** (`RemoteSigned`) en el ámbito `CurrentUser`, con fallback a `LocalMachine` y `Process` si hay GPO.
- Habilita **TLS 1.2** y registra **NuGet** como proveedor de paquetes.
- Marca **PSGallery** como fuente de confianza.

### 2 · Escribe el `$PROFILE`
Genera y sobrescribe `Microsoft.PowerShell_profile.ps1` para **PS 7** y **PS 5.1** simultáneamente. Antes de sobreescribir, crea un backup con timestamp automático.

El profile generado incluye:
- **PATH extra** para Git (`\bin` y `\cmd`), comprobado en cada sesión.
- **PSReadLine** — historial incremental, 20 000 entradas, predicción por historial, ListView (si versión ≥ 2.2), atajos `Tab / Ctrl+R / ↑ / ↓`.
- **posh-git** — carga solo si `git.exe` está disponible.
- **Terminal-Icons** — iconos de fichero y carpeta en `ls`.
- **ExchangeOnlineManagement** — carga *lazy*: el módulo no se importa al inicio, solo al ejecutar `Connect-ExchangeOnline` por primera vez (evita 4-8 s de latencia).
- **Microsoft.Graph** — carga *lazy*: ídem al ejecutar `Connect-MgGraph`.
- **Alias** — `ll` → `Get-ChildItem`, `g` → `git`.
- **Helpers** — `which <cmd>` y `touch <fichero>`.
- **Prompt personalizado** — formato `[HH:mm] ruta  [rama-git] >` en cyan, con la rama actual del repositorio.
- **Directorio de inicio** configurable; se aplica solo en la primera apertura de la sesión.

### 3 · Instala módulos de PowerShell
| Módulo | Versión mínima |
|---|---|
| PSReadLine | 2.3.6 |
| Terminal-Icons | última disponible |
| posh-git | última disponible |
| ExchangeOnlineManagement | última disponible |
| Microsoft.Graph | última disponible |

> Si PSReadLine no puede instalarse en `AllUsers` (sin admin o GPO), el instalador reintenta automáticamente en `CurrentUser`.

### 4 · Instala paquetes vía winget
| Paquete | ID winget |
|---|---|
| PowerShell 7 | `Microsoft.PowerShell` *(solo si no está instalado)* |
| Git | `Git.Git` |
| Python 3.12 | `Python.Python.3.12` |
| .NET SDK 8 (LTS) | `Microsoft.DotNet.SDK.8` |
| Windows Terminal | `Microsoft.WindowsTerminal` |
| JetBrainsMono Nerd Font | `DEVCOM.JetBrainsMonoNerdFont` |

Si el paquete ya está presente, ejecuta `winget upgrade` en lugar de reinstalar.

---

## Requisitos

- Windows 10 / 11
- `winget` disponible (preinstalado en Windows 11; en Windows 10 se obtiene desde la Microsoft Store)
- Ejecutar como **Administrador** (para instalar módulos en `AllUsers` y paquetes del sistema)

---

## Instalación

```bat
INSTALAR.bat
```

Doble clic. El `.bat` detecta si tiene privilegios de administrador y, si no los tiene, se relanza elevado automáticamente. Elige el mejor host disponible (`pwsh` o `powershell`) y ejecuta `setup_terminal.ps1`.

También puedes lanzarlo directamente desde PowerShell:

```powershell
# Con directorio de inicio interactivo
.\setup_terminal.ps1

# Con directorio de inicio predefinido (sin prompt)
.\setup_terminal.ps1 -StartPath "C:\proyectos"

# Solo configurar profile y módulos, sin instalar paquetes
.\setup_terminal.ps1 -SkipInstalls
```

---

## Pasos manuales tras la instalación

### Ocultar el banner de copyright y el tiempo de carga
En Windows Terminal → Configuración → Perfiles → PowerShell, sustituye el campo **Línea de comandos** por:

```
pwsh -NoLogo -NoProfileLoadTime
```

### Activar los iconos de Terminal-Icons
En Windows Terminal → Configuración → Perfiles → PowerShell → **Apariencia**, cambia el tipo de fuente a:

```
JetBrainsMono Nerd Font
```

Si no aparece en la lista, cierra y vuelve a abrir Windows Terminal (las fuentes recién instaladas necesitan que el proceso se reinicie).

---

## Comportamiento idempotente

El script es seguro de ejecutar varias veces:
- Los módulos ya instalados se omiten (no se reinstalan).
- Los paquetes winget ya presentes solo reciben `upgrade`.
- El `$PROFILE` existente recibe un backup antes de sobreescribirse.
- PowerShell 7 no se reinstala si ya está detectado en el sistema.

---

## Estructura del repositorio

```
TermixPS/
├── INSTALAR.bat          # Lanzador con auto-elevación
└── setup_terminal.ps1    # Script principal de configuración
```
