# ⚡ TERMIX v2.1

> One script. Full PowerShell environment. Zero manual setup.

Windows 10/11 | PowerShell 7+ | MIT License

---

## 📦 ¿Qué hace?

Ejecuta INSTALAR.bat y el sistema se configura automáticamente:

- Execution Policy -> RemoteSigned en CurrentUser (fallback Process si hay GPO)
- Perfil ($PROFILE) -> Generado para PS7 y PS5.1 con backup automático del anterior
- Módulos esenciales -> PSReadLine 2.3.6+, Terminal-Icons, posh-git
- Paquetes (winget) -> Git, Python 3.12, .NET SDK 8, Windows Terminal, JetBrainsMono Nerd Font
- PowerShell 7 -> Instalado automáticamente si no está presente

---

## 🚀 Carga del perfil

Cada vez que abres una terminal se carga esto:

PSReadLine     -> historial incremental, predicción, ListView, atajos ↑↓
posh-git       -> muestra la rama actual en el prompt (solo si git.exe existe)
Terminal-Icons -> iconos en ls/dir

Prompt resultante:

[22:47] C:\proyectos  [main] >

---

## 🛠️ Despliegue

INSTALAR.bat                           -> Doble clic — se auto-eleva si requiere administrador
.\setup_terminal.ps1 -StartPath "C:\dev" -> Fija directorio de inicio
.\setup_terminal.ps1 -SkipInstalls     -> Solo perfil + módulos, sin winget

---

## ⚙️ Configuración post-instalación (Windows Terminal)

1. Abre Windows Terminal
2. Haz clic en la flecha hacia abajo (∨) en la barra superior
3. Ve a Configuración
4. En la lista de perfiles, selecciona PowerShell.
5. Busca el campo Línea de comandos y pega:
   pwsh -NoLogo -NoProfileLoadTime
6. Guarda los cambios

Opcional – fuente recomendada:
En el mismo perfil, ve a Apariencia -> Fuente -> JetBrainsMono Nerd Font

---

## ♻️ Idempotencia

El script es seguro de relanzar:
- No reinstala lo que ya existe
- Crea un backup con timestamp antes de sobrescribir $PROFILE
- Requiere Windows 10/11, winget y permisos de administrador

---

Hecho con 🧠 para que no tengas que hacer nada
