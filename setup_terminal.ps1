[CmdletBinding()]
param(
    [switch]$SkipInstalls,
    [string]$StartPath,
    [switch]$Unattended
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$script:Failures       = @()

# Forzar UTF-8 en entrada y salida de la consola (evita "las no se reconoce" por mojibake)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

# ── UI helpers ───────────────────────────────────────────────
function Write-Step { param($m) Write-Host "`n  > $m" -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Info { param($m) Write-Host "    [..] $m" -ForegroundColor DarkGray }
function Write-Warn2{ param($m) Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Fail2{ param($m) Write-Host "    [X]  $m" -ForegroundColor Red; $script:Failures += $m }

# ── Banner ───────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ████████╗███████╗██████╗ ███╗   ███╗██╗██╗  ██╗" -ForegroundColor Magenta
Write-Host "  ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║╚██╗██╔╝" -ForegroundColor Magenta
Write-Host "     ██║   █████╗  ██████╔╝██╔████╔██║██║ ╚███╔╝ " -ForegroundColor Magenta
Write-Host "     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║ ██╔██╗ " -ForegroundColor Cyan
Write-Host "     ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██╔╝ ██╗" -ForegroundColor Cyan
Write-Host "     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "        Customizable console + modules" -ForegroundColor White
Write-Host "        ────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "        config → modules → packages   v2.1"   -ForegroundColor DarkGray
Write-Host ""

# ── 0. Comprobaciones previas ────────────────────────────────
Write-Step "Comprobaciones previas"

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) { Write-OK "Ejecutando como administrador" }
else          { Write-Warn2 "Sin privilegios admin; las instalaciones pueden fallar." }

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if ($hasWinget) { Write-OK "winget disponible" }
else            { Write-Warn2 "winget ausente; se saltarán las instalaciones." }

# Detección real de PowerShell 7 (no solo por PATH)
function Find-Pwsh {
    $candidates = @(
        (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source,
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    return $candidates
}
$pwshExe = Find-Pwsh
$ps7Installed = [bool]$pwshExe
if ($ps7Installed) { Write-OK "PowerShell 7 detectado: $pwshExe" }
else               { Write-Info "PowerShell 7 no detectado (se instalará al final)" }

# ── 1. Directorio inicial ────────────────────────────────────
Write-Step "Directorio de inicio del terminal"

$defaultPath = Join-Path $env:USERPROFILE 'Documents'

# Detección de modo no-interactivo (stdin redirigido, sin host UI, o flag explícito)
$nonInteractive = $Unattended -or `
                  [Console]::IsInputRedirected -or `
                  -not [Environment]::UserInteractive

function Resolve-WorkDir {
    param([string]$Candidate, [string]$Fallback)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $Fallback }
    $c = $Candidate.Trim().Trim('"').Trim("'")
    # Validar caracteres ilegales en ruta
    $invalid = [IO.Path]::GetInvalidPathChars()
    if ($c.IndexOfAny($invalid) -ge 0) { return $null }
    return $c
}

if ($StartPath) {
    $workDir = Resolve-WorkDir -Candidate $StartPath -Fallback $defaultPath
    if (-not $workDir) {
        Write-Warn2 "Ruta -StartPath no válida. Usando $defaultPath."
        $workDir = $defaultPath
    }
} elseif ($nonInteractive) {
    Write-Info "Modo desatendido, usando ruta por defecto: $defaultPath"
    $workDir = $defaultPath
} else {
    Write-Host "    Deja vacío para usar: $defaultPath" -ForegroundColor DarkGray
    $attempts = 0
    do {
        $userInput = Read-Host "    Ruta"
        $workDir = Resolve-WorkDir -Candidate $userInput -Fallback $defaultPath
        if (-not $workDir) {
            Write-Warn2 "Ruta no válida. Inténtalo de nuevo o deja vacío."
            $attempts++
        }
    } while (-not $workDir -and $attempts -lt 3)
    if (-not $workDir) {
        Write-Warn2 "Demasiados intentos. Usando $defaultPath."
        $workDir = $defaultPath
    }
}

if (-not (Test-Path $workDir)) {
    try {
        New-Item -ItemType Directory -Path $workDir -Force -ErrorAction Stop | Out-Null
        Write-OK "Carpeta creada: $workDir"
    } catch {
        Write-Warn2 "No se pudo crear '$workDir' ($($_.Exception.Message)). Usando $defaultPath."
        $workDir = $defaultPath
        if (-not (Test-Path $workDir)) {
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        }
    }
} else {
    Write-OK "Directorio: $workDir"
}

# ── 2. Execution Policy ──────────────────────────────────────
Write-Step "Execution Policy"
try {
    $effective = Get-ExecutionPolicy

    if ($effective -in @('Restricted','AllSigned','Undefined')) {
        # Intentar CurrentUser primero
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            Write-OK "Policy CurrentUser -> RemoteSigned"
        } catch {
            # Fallback: LocalMachine (requiere admin) y, si no, Process
            try {
                Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
                Write-OK "Policy LocalMachine -> RemoteSigned"
            } catch {
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                Write-Warn2 "Bloqueada por GPO. Aplicado Bypass solo a este proceso."
            }
        }
    } else {
        Write-OK "Policy OK ($effective)"
    }
} catch { Write-Warn2 "No se pudo ajustar Execution Policy: $($_.Exception.Message)" }

# ── 3. PowerShellGet / NuGet / PSGallery ─────────────────────
Write-Step "Preparando PowerShellGet + PSGallery"
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
              Where-Object Version -ge '2.8.5.201')) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        Write-OK "NuGet provider instalado"
    } else { Write-OK "NuGet provider OK" }

    if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-OK "PSGallery -> Trusted"
    } else { Write-OK "PSGallery ya es Trusted" }
} catch { Write-Warn2 "PowerShellGet: $($_.Exception.Message)" }

# ── 4. Escribir profile (sobrescribe siempre) ────────────────
Write-Step "Escribiendo profile de PowerShell (sobrescribe el existente)"

$ps7ProfileDir  = Join-Path $env:USERPROFILE 'Documents\PowerShell'
$ps7ProfilePath = Join-Path $ps7ProfileDir 'Microsoft.PowerShell_profile.ps1'
$ps5ProfileDir  = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
$ps5ProfilePath = Join-Path $ps5ProfileDir 'Microsoft.PowerShell_profile.ps1'

foreach ($d in @($ps7ProfileDir, $ps5ProfileDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

$escapedPath = $workDir -replace "'", "''"

$profileContent = @"
# ─── Generado por TERMIX  ────────────────────────────────────

# Extra PATH (Git)
foreach (`$p in @('C:\Program Files\Git\bin', 'C:\Program Files\Git\cmd')) {
    if ((Test-Path `$p) -and (`$env:Path -notlike "*`$p*")) { `$env:Path += ";`$p" }
}

# PSReadLine
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    `$psrlVer = (Get-Module PSReadLine).Version
    `$psrlOpts = @{
        HistorySaveStyle    = 'SaveIncrementally'
        MaximumHistoryCount = 20000
        BellStyle           = 'None'
        EditMode            = 'Windows'
        ErrorAction         = 'SilentlyContinue'
    }
    if (`$psrlVer -ge [version]'2.1.0') { `$psrlOpts.PredictionSource = 'History' }
    Set-PSReadLineOption @psrlOpts
    if (`$psrlVer -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    }
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete          -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+r    -Function ReverseSearchHistory  -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward  -ErrorAction SilentlyContinue
}

# posh-git (solo si git disponible)
if (Get-Command git.exe -ErrorAction SilentlyContinue) {
    Import-Module posh-git -ErrorAction SilentlyContinue
}

# Terminal-Icons
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# ExchangeOnlineManagement: carga lazy (evita 4-8 s de inicio)
if (Get-Module -ListAvailable ExchangeOnlineManagement) {
    function Connect-ExchangeOnline {
        Remove-Item Function:Connect-ExchangeOnline -ErrorAction SilentlyContinue
        Import-Module ExchangeOnlineManagement -DisableNameChecking -ErrorAction SilentlyContinue
        & (Get-Command Connect-ExchangeOnline -Module ExchangeOnlineManagement) @args
    }
}

# Microsoft.Graph: carga lazy
if (Get-Module -ListAvailable Microsoft.Graph.Authentication) {
    function Connect-MgGraph {
        Remove-Item Function:Connect-MgGraph -ErrorAction SilentlyContinue
        Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
        & (Get-Command Connect-MgGraph -Module Microsoft.Graph.Authentication) @args
    }
}

# Alias y helpers
Set-Alias ll Get-ChildItem
Set-Alias g  git
function which(`$cmd) { (Get-Command `$cmd -ErrorAction SilentlyContinue).Source }
function touch(`$f)   { if (Test-Path `$f) { (Get-Item `$f).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path `$f | Out-Null } }

# Cache: comprobar git una sola vez al inicio
`$script:_hasGit = [bool](Get-Command git.exe -ErrorAction SilentlyContinue)

# Prompt
function prompt {
    `$path   = (Get-Location).Path
    `$branch = ''
    if (`$script:_hasGit) {
        `$b = git branch --show-current 2>`$null
        if (`$b) { `$branch = "  [`$b]" }
    }
    Write-Host "[`$((Get-Date).ToString('HH:mm'))] `$path`$branch > " -ForegroundColor Cyan -NoNewline
    return ' '
}

# Directorio inicial (solo la 1.a vez en la sesión)
if (-not `$global:__TermixStarted) {
    Set-Location '$escapedPath'
    `$global:__TermixStarted = `$true
    Clear-Host
}
"@

foreach ($target in @(@{Path=$ps7ProfilePath; Tag='PS7'}, @{Path=$ps5ProfilePath; Tag='PS5.1'})) {
    try {
        if (Test-Path $target.Path) {
            $backup = "$($target.Path).bak-$(Get-Date -Format yyyyMMddHHmmss)"
            Copy-Item $target.Path $backup -Force
            Write-Info "Backup previo: $backup"
        }
        Set-Content -Path $target.Path -Value $profileContent -Encoding UTF8 -Force
        Write-OK "Profile $($target.Tag): $($target.Path)"
    } catch { Write-Fail2 "Profile $($target.Tag): $($_.Exception.Message)" }
}

# ── 5. Módulos de PowerShell ─────────────────────────────────
Write-Step "Instalando módulos de PowerShell"

function Install-PSModuleIfMissing {
    param([string]$Name)
    try {
        if (Get-Module -ListAvailable -Name $Name) {
            Write-OK "$Name ya instalado"
        } else {
            Write-Info "Instalando $Name..."
            Install-Module $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-OK "$Name instalado"
        }
    } catch { Write-Fail2 "${Name}: $($_.Exception.Message)" }
}

# PSReadLine: forzar 2.3+ (la 2.0 de PS5.1 no tiene ListView)
try {
    $psrlTarget = '2.3.6'
    $installed  = Get-Module PSReadLine -ListAvailable |
                  Sort-Object Version -Descending | Select-Object -First 1
    if (-not $installed -or $installed.Version -lt [version]$psrlTarget) {
        Write-Info "Instalando PSReadLine $psrlTarget (AllUsers)..."
        Install-Module PSReadLine -RequiredVersion $psrlTarget `
            -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber `
            -ErrorAction Stop
        Write-OK "PSReadLine $psrlTarget instalado"
    } else {
        Write-OK "PSReadLine $($installed.Version) ya cumple (>=$psrlTarget)"
    }
} catch {
    # Fallback a CurrentUser si AllUsers falla (sin admin o GPO)
    try {
        Install-Module PSReadLine -RequiredVersion '2.3.6' `
            -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber `
            -ErrorAction Stop
        Write-OK "PSReadLine 2.3.6 instalado (CurrentUser fallback)"
    } catch { Write-Fail2 "PSReadLine: $($_.Exception.Message)" }
}

$modules = @(
    'Terminal-Icons',
    'posh-git',
    'ExchangeOnlineManagement',
    'Microsoft.Graph'
)
foreach ($m in $modules) { Install-PSModuleIfMissing -Name $m }

# ── 6. Instalación de paquetes vía winget (AL FINAL) ─────────
function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id, [string]$Name = $Id)
    if (-not $hasWinget) { Write-Warn2 "Omitido $Name (winget ausente)"; return }
    try {
        $listed = winget list --id $Id -e --accept-source-agreements 2>$null | Out-String
        if ($listed -match [Regex]::Escape($Id)) {
            Write-Info "$Name ya presente, comprobando updates..."
            winget upgrade --id $Id -e --silent `
                --accept-package-agreements --accept-source-agreements `
                --disable-interactivity 2>&1 | Out-Null
            Write-OK "$Name al día"
        } else {
            Write-Info "Instalando $Name..."
            winget install --id $Id -e --silent `
                --accept-package-agreements --accept-source-agreements `
                --disable-interactivity 2>&1 | Out-Null
            Write-OK "$Name instalado"
        }
    } catch { Write-Fail2 "${Name}: $($_.Exception.Message)" }
}

if (-not $SkipInstalls) {
    Write-Step "Instalando / actualizando paquetes base (esto puede tardar)"

    $packages = @(
        @{ Id='Git.Git';                       Name='Git' }
        @{ Id='Python.Python.3.12';            Name='Python 3.12' }
        @{ Id='Microsoft.DotNet.SDK.8';        Name='.NET SDK 8 (LTS)' }
        @{ Id='Microsoft.WindowsTerminal';     Name='Windows Terminal' }
        @{ Id='DEVCOM.JetBrainsMonoNerdFont';  Name='JetBrainsMono Nerd Font' }
    )

    # PowerShell 7: solo si NO está instalado ya
    if (-not $ps7Installed) {
        $packages = ,@{ Id='Microsoft.PowerShell'; Name='PowerShell 7' } + $packages
    } else {
        Write-OK "PowerShell 7 ya instalado, se omite (no se reinstala)"
    }

    foreach ($p in $packages) { Install-WingetPackage -Id $p.Id -Name $p.Name }

    # Refrescar PATH dentro de la sesión actual
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')

    # Reintentar detección de pwsh por si se acaba de instalar
    if (-not $pwshExe) { $pwshExe = Find-Pwsh }
} else {
    Write-Info "SkipInstalls activo, se omite winget."
}

# ── 8. Guía manual: configurar pwsh sin banner en Windows Terminal
Write-Host ""
Write-Host "  ─── PASO MANUAL: ocultar banner / tiempos en PS7 ───" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Para que cada vez que abras una pestaña nueva NO se muestre" -ForegroundColor White
Write-Host "   la cabecera de copyright ni el tiempo de carga del profile:" -ForegroundColor White
Write-Host ""
Write-Host "     1. Abre Windows Terminal." -ForegroundColor Gray
Write-Host "     2. Flechita ˅ junto a las pestañas → Configuración." -ForegroundColor Gray
Write-Host "     3. En la barra lateral, sección 'Perfiles' → PowerShell." -ForegroundColor Gray
Write-Host "     4. Busca el campo 'Línea de comandos' y sustitúyelo por:" -ForegroundColor Gray
Write-Host ""
Write-Host '        pwsh -NoLogo -NoProfileLoadTime' -ForegroundColor Yellow
Write-Host ""
Write-Host "     5. Guardar. Abre una pestaña nueva y listo." -ForegroundColor Gray
Write-Host ""
Write-Host "   Qué hace cada flag:" -ForegroundColor DarkGray
Write-Host "     -NoLogo            → oculta el banner de copyright." -ForegroundColor DarkGray
Write-Host "     -NoProfileLoadTime → oculta el aviso de tiempo de carga." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ─── PASO MANUAL: activar la Nerd Font (iconos de ls) ───" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Si al hacer 'ls' ves cuadritos en vez de iconos, falta" -ForegroundColor White
Write-Host "   cambiar la fuente del terminal:" -ForegroundColor White
Write-Host ""
Write-Host "     1. Windows Terminal → Configuración (Ctrl + ,)" -ForegroundColor Gray
Write-Host "     2. Perfiles → PowerShell → Apariencia." -ForegroundColor Gray
Write-Host "     3. En 'Tipo de fuente' selecciona:" -ForegroundColor Gray
Write-Host ""
Write-Host '        JetBrainsMono Nerd Font' -ForegroundColor Yellow
Write-Host ""
Write-Host "     4. Guardar. Abre una pestaña nueva → ls mostrará iconos." -ForegroundColor Gray
Write-Host ""
Write-Host "   (Si no aparece en la lista, reinicia Windows Terminal o" -ForegroundColor DarkGray
Write-Host "    cierra/abre sesión: las fuentes recién instaladas necesitan" -ForegroundColor DarkGray
Write-Host "    refrescarse en el sistema.)" -ForegroundColor DarkGray
Write-Host ""

if (-not $StartPath) { Read-Host "  Pulsa Enter para cerrar" | Out-Null }
exit ([int]([bool]$script:Failures.Count))
