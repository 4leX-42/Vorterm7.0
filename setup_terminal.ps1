# =============================================================
#  Vorterm 7.1  (WPF GUI)
#  Run via INSTALAR.bat (powershell.exe -STA -WindowStyle Hidden)
#
#  CLI (sin GUI, para pruebas):
#    powershell -STA -File setup_terminal.ps1 -NoGui -DryRun
#    -NoGui  : ejecuta en consola, sin ventana
#    -DryRun : simula todo, no toca NADA del sistema
# =============================================================

[CmdletBinding()]
param(
    [switch]$NoGui,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

if (-not $NoGui) {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
}

# Process suspend/resume P/Invoke (used for Pause button during install)
if (-not ('Vorterm.ProcCtl' -as [type])) {
    Add-Type -Namespace Vorterm -Name ProcCtl -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("ntdll.dll")]
public static extern int NtSuspendProcess(System.IntPtr handle);
[System.Runtime.InteropServices.DllImport("ntdll.dll")]
public static extern int NtResumeProcess(System.IntPtr handle);
'@
}

# DWM: barra de titulo oscura (por defecto Windows la pinta blanca en apps Win32/WPF)
if (-not ('Vorterm.Dwm' -as [type])) {
    Add-Type -Namespace Vorterm -Name Dwm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
'@
}

# ------ Prompt theme (Mainthema) -----------------------------
# Se instala en ~\.poshthemes\Mainthema.json. Prioridad:
#   1. Mainthema.json junto al script (repo)
#   2. Copia embebida (fallback, mismo contenido)
$script:ThemeFileName = 'Mainthema.json'
$script:ThemeSrc = $null
if ($PSScriptRoot) {
    $cand = Join-Path $PSScriptRoot $script:ThemeFileName
    if (Test-Path $cand) { $script:ThemeSrc = $cand }
}
$script:ThemeJson = @'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "blocks": [
    {
      "alignment": "left",
      "segments": [
        {
          "foreground": "#FFFFFF",
          "style": "plain",
          "template": "┏[]",
          "type": "text"
        },
        {
          "foreground": "#00FFFF",
          "options": {
            "style": "agnoster_short",
            "max_depth": 3
          },
          "style": "plain",
          "template": "<#FFFFFF>[</>{{ .Path }}<#FFFFFF>]</>",
          "type": "path"
        },
        {
          "foreground": "#FFA500",
          "style": "plain",
          "template": "<#FFFFFF>[</> {{ .UserName }}<#FFFFFF>]</>",
          "type": "session"
        },
        {
          "foreground": "#FF0033",
          "style": "plain",
          "template": "<#FFFFFF>git:</>{{ .HEAD }}",
          "type": "git"
        },
        {
          "foreground": "#FF0033",
          "style": "plain",
          "template": "{{ if gt .Code 0 }} <#FFFFFF>[x</>{{ reason .Code }}<#FFFFFF>]</>{{ end }}",
          "type": "status"
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "foreground": "#FFFFFF",
          "style": "plain",
          "template": "┖>",
          "type": "text"
        }
      ],
      "type": "prompt"
    }
  ],
  "final_space": true,
  "version": 4
}
'@

# =============================================================
#  INSTALL LOGIC (compartida: runspace GUI + modo consola)
#  Espera en scope: $sync (hashtable), $opts (hashtable)
# =============================================================
$InstallLogic = {

    function Write-Log {
        param([string]$Msg)
        if ($sync.NoGui) { Write-Host $Msg; return }
        $sync.Window.Dispatcher.Invoke([action]{
            $color = '#d9d9d9'
            if     ($Msg -match '\[OK\]')  { $color = '#fcee0a' }
            elseif ($Msg -match '\[!!\]')  { $color = '#ff2b4a' }
            elseif ($Msg -match '\[DRY\]') { $color = '#66d9ff' }
            elseif ($Msg -match '\[\.\.\]'){ $color = '#6a6c70' }
            elseif ($Msg -match '^\s*=+')  { $color = '#8a8104' }
            $run = New-Object System.Windows.Documents.Run($Msg)
            $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($color)
            [void]$sync.LogPara.Inlines.Add($run)
            [void]$sync.LogPara.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
            $sync.LogBox.ScrollToEnd()
        })
    }
    function Set-Status {
        param([string]$Text, [int]$Pct = -1)
        if ($sync.NoGui) { Write-Host ">> $Text" -ForegroundColor DarkYellow; return }
        $sync.Window.Dispatcher.Invoke([action]{
            $sync.StatusText.Text = $Text
            if ($Pct -ge 0) { $sync.Progress.Value = $Pct }
        })
    }

    $started = Get-Date
    $script:failures = @()
    $DRY = [bool]$opts.DryRun

    try {

        Write-Log "============================================================"
        Write-Log "  Vorterm install  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "  Startup dir: $($opts.WorkDir)"
        if ($DRY) {
        Write-Log "  MODO DRY RUN - simulacion, no se modifica NADA"
        }
        Write-Log "============================================================"
        Write-Log ""

        # ---- Pre-flight ----------------------------------
        Set-Status 'Pre-check' 2

        $isAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Write-Log ("  [{0}] admin rights: {1}" -f $(if($isAdmin){'OK'}else{'..'}), $isAdmin)

        $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        Write-Log ("  [{0}] winget available" -f $(if($hasWinget){'OK'}else{'!!'}))

        function Find-Pwsh {
            @(
                (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source,
                "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
                "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe"
            ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        }
        $pwshExe = Find-Pwsh
        Write-Log ("  [{0}] pwsh.exe: {1}" -f $(if($pwshExe){'OK'}else{'..'}), $(if($pwshExe){$pwshExe}else{'(not yet installed)'}))

        # ---- Workdir -------------------------------------
        Set-Status 'Workdir' 5
        if (-not (Test-Path $opts.WorkDir)) {
            if ($DRY) {
                Write-Log "  [DRY] crearia dir: $($opts.WorkDir)"
            } else {
                try {
                    New-Item -ItemType Directory -Path $opts.WorkDir -Force | Out-Null
                    Write-Log "  [OK] created: $($opts.WorkDir)"
                } catch {
                    Write-Log "  [!!] could not create, fallback to Documents"
                    $opts.WorkDir = Join-Path $env:USERPROFILE 'Documents'
                }
            }
        } else { Write-Log "  [OK] dir exists" }

        # ---- Execution policy ----------------------------
        if ($opts.Policy) {
            Set-Status 'Policy' 8
            try {
                $eff = Get-ExecutionPolicy
                if ($eff -in @('Restricted','AllSigned','Undefined')) {
                    if ($DRY) {
                        Write-Log "  [DRY] policy CurrentUser -> RemoteSigned (actual: $eff)"
                    } else {
                        try {
                            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
                            Write-Log "  [OK] policy CurrentUser -> RemoteSigned"
                        } catch {
                            Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                            Write-Log "  [!!] GPO blocked. Process scope -> Bypass"
                        }
                    }
                } else {
                    Write-Log "  [OK] policy already $eff"
                }
            } catch { Write-Log "  [!!] policy: $($_.Exception.Message)" }
        }

        # ---- PSGallery prep ------------------------------
        Set-Status 'PSGallery' 12
        try {
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
                      Where-Object Version -ge '2.8.5.201')) {
                if ($DRY) {
                    Write-Log "  [DRY] instalaria NuGet provider >= 2.8.5.201"
                } else {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
                    Write-Log "  [OK] NuGet provider installed"
                }
            } else { Write-Log "  [OK] NuGet provider" }

            if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
                if ($DRY) {
                    Write-Log "  [DRY] PSGallery -> Trusted"
                } else {
                    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                    Write-Log "  [OK] PSGallery -> Trusted"
                }
            } else { Write-Log "  [OK] PSGallery trusted" }
        } catch { Write-Log "  [!!] gallery: $($_.Exception.Message)" }

        # ---- Winget packages (SECUENCIAL + retry) --------
        # Antes iban en paralelo: los instaladores MSI chocan entre si
        # (ERROR_INSTALL_ALREADY_RUNNING 1618) y fallan aleatoriamente.
        # Secuencial con 1 retry es mas lento pero fiable.
        Set-Status 'Packages' 18

        $pkgs = @()
        if ($opts.Pwsh -and -not $pwshExe) {
            $pkgs += @{ Id='Microsoft.PowerShell';        Name='PowerShell 7' }
        } elseif ($opts.Pwsh) {
            Write-Log "  [OK] PowerShell 7 already installed"
        }
        function Test-Optional {
            param([string]$Cmd, [string[]]$Paths)
            if ($Cmd -and (Get-Command $Cmd -ErrorAction SilentlyContinue)) { return $true }
            foreach ($p in $Paths) { if ($p -and (Test-Path $p)) { return $true } }
            return $false
        }
        function Test-FontInstalled {
            param([string]$Pattern)
            foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                              'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
                if (Test-Path $hive) {
                    $names = (Get-ItemProperty $hive).PSObject.Properties |
                             Where-Object { $_.Name -notlike 'PS*' } |
                             Select-Object -ExpandProperty Name
                    if ($names -match $Pattern) { return $true }
                }
            }
            return $false
        }
        if ($opts.Git) {
            if (Test-Optional 'git' @("$env:ProgramFiles\Git\cmd\git.exe","$env:ProgramFiles\Git\bin\git.exe")) {
                Write-Log "  [OK] Git already installed"
            } else { $pkgs += @{ Id='Git.Git'; Name='Git' } }
        }
        if ($opts.WT) {
            $wtPath = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
            if ($wtPath) {
                Write-Log "  [OK] Windows Terminal already installed"
            } else { $pkgs += @{ Id='Microsoft.WindowsTerminal'; Name='Windows Terminal' } }
        }
        if ($opts.Font) {
            if (Test-FontInstalled '(?i)JetBrainsMono.*(Nerd\s*Font|\bN[FL][MP]?\b)') {
                Write-Log "  [OK] JetBrainsMono Nerd Font already installed"
            } else { $pkgs += @{ Id='DEVCOM.JetBrainsMonoNerdFont'; Name='JetBrainsMono Nerd Font' } }
        }
        if ($opts.OMP) {
            if (Test-Optional 'oh-my-posh' @("$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe",
                                              "$env:LOCALAPPDATA\Microsoft\WindowsApps\oh-my-posh.exe")) {
                Write-Log "  [OK] oh-my-posh already installed"
            } else { $pkgs += @{ Id='JanDeDobbeleer.OhMyPosh'; Name='oh-my-posh' } }
        }

        if ($opts.VSCode) {
            if (Test-Optional 'code' @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
                                        "$env:ProgramFiles\Microsoft VS Code\Code.exe")) {
                Write-Log "  [OK] VS Code already installed"
            } else { $pkgs += @{ Id='Microsoft.VisualStudioCode'; Name='Visual Studio Code' } }
        }
        if ($opts.Neovim) {
            if (Test-Optional 'nvim' @("$env:ProgramFiles\Neovim\bin\nvim.exe")) {
                Write-Log "  [OK] Neovim already installed"
            } else { $pkgs += @{ Id='Neovim.Neovim'; Name='Neovim' } }
        }
        if ($opts.SevenZip) {
            if (Test-Optional $null @("$env:ProgramFiles\7-Zip\7z.exe")) {
                Write-Log "  [OK] 7-Zip already installed"
            } else { $pkgs += @{ Id='7zip.7zip'; Name='7-Zip' } }
        }
        if ($opts.GitHubDesktop) {
            if (Test-Optional $null @("$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe")) {
                Write-Log "  [OK] GitHub Desktop already installed"
            } else { $pkgs += @{ Id='GitHub.GitHubDesktop'; Name='GitHub Desktop' } }
        }

        if ($hasWinget -and $pkgs.Count -gt 0 -and $DRY) {
            foreach ($p in $pkgs) {
                Write-Log "  [DRY] winget install --id $($p.Id) -e --silent   ($($p.Name))"
            }
        } elseif ($hasWinget -and $pkgs.Count -gt 0) {
            Write-Log "  [..] installing $($pkgs.Count) packages (sequential, reliable)..."

            # Snapshot desktop shortcuts so we can clean up new ones afterwards
            $desktopDirs = @([Environment]::GetFolderPath('Desktop'),
                             [Environment]::GetFolderPath('CommonDesktopDirectory')) |
                           Where-Object { $_ -and (Test-Path $_) }
            $desktopBefore = @{}
            foreach ($d in $desktopDirs) {
                $desktopBefore[$d] = @(Get-ChildItem $d -Filter '*.lnk' -File -ErrorAction SilentlyContinue |
                                       Select-Object -ExpandProperty Name)
            }

            # Show Pause button while installs run
            if (-not $sync.NoGui) {
                $sync.Window.Dispatcher.Invoke([action]{
                    $sync.PauseBtn.Visibility = [System.Windows.Visibility]::Visible
                    $sync.PauseBtn.Content = 'Pause'
                })
            }

            # winget exit codes ok: 0; -1978335189 = no upgrade; -1978335212 = no applicable
            $okCodes = @(0, -1978335189, -1978335212)
            # retry-ables: 1618 / 0x80070652 = otro instalador MSI en curso
            $busyCodes = @(1618, -2147023278)

            $total = $pkgs.Count
            $idx = 0
            foreach ($p in $pkgs) {
                $idx++
                $basePct = 18 + [int](37 * ($idx - 1) / $total)
                Set-Status "Packages ($idx/$total): $($p.Name)" $basePct
                Write-Log "  [..] installing $($p.Name)..."

                $wingetArgs = @(
                    'install','--id',$p.Id,'-e','--silent',
                    '--source','winget',
                    '--accept-package-agreements','--accept-source-agreements',
                    '--disable-interactivity'
                )

                $code = $null
                foreach ($attempt in 1,2) {
                    $proc = Start-Process winget -ArgumentList $wingetArgs -WindowStyle Hidden -PassThru
                    if (-not $sync.NoGui) {
                        $sync.Window.Dispatcher.Invoke([action]{ [void]$sync.ActiveProcs.Add($proc) })
                    }
                    while (-not $proc.HasExited) {
                        Start-Sleep -Milliseconds 300
                        if ($sync.Paused) { Set-Status "Packages paused ($idx/$total)" $basePct }
                    }
                    if (-not $sync.NoGui) {
                        $sync.Window.Dispatcher.Invoke([action]{ $sync.ActiveProcs.Clear() })
                    }
                    $code = $proc.ExitCode
                    if ($okCodes -contains $code) { break }
                    if (($busyCodes -contains $code) -and $attempt -eq 1) {
                        Write-Log ("  [..] {0}: otro instalador ocupado (0x{1:X8}), retry en 15s..." -f $p.Name, $code)
                        Start-Sleep -Seconds 15
                        continue
                    }
                    break
                }

                if ($okCodes -contains $code) {
                    Write-Log ("  [OK] {0}" -f $p.Name)
                } else {
                    Write-Log ("  [!!] {0} (exit 0x{1:X8})" -f $p.Name, $code)
                    $script:failures += $p.Name
                }
            }

            if (-not $sync.NoGui) {
                $sync.Window.Dispatcher.Invoke([action]{
                    $sync.PauseBtn.Visibility = [System.Windows.Visibility]::Collapsed
                    $sync.ActiveProcs.Clear()
                    $sync.Paused = $false
                })
            }

            # Cleanup desktop shortcuts created by installers
            foreach ($d in $desktopDirs) {
                $now = Get-ChildItem $d -Filter '*.lnk' -File -ErrorAction SilentlyContinue
                foreach ($lnk in $now) {
                    if ($desktopBefore[$d] -notcontains $lnk.Name) {
                        try {
                            Remove-Item $lnk.FullName -Force -ErrorAction Stop
                            Write-Log "  [OK] removed desktop shortcut: $($lnk.Name)"
                        } catch {}
                    }
                }
            }
        } elseif (-not $hasWinget -and $pkgs.Count) {
            Write-Log "  [!!] winget missing, skipping all packages"
        }

        # ---- Font fallback: descarga directa si winget no la dejo instalada ---
        # En equipos nuevos winget a veces falla con la fuente (source desactualizado,
        # scope maquina sin admin...). Plan B: zip oficial de nerd-fonts e instalacion
        # por usuario (LOCALAPPDATA\...\Fonts + HKCU), sin necesidad de admin.
        if ($opts.Font -and -not $DRY -and
            -not (Test-FontInstalled '(?i)JetBrainsMono.*(Nerd\s*Font|\bN[FL][MP]?\b)')) {
            Set-Status 'Font (direct download)' 56
            Write-Log "  [..] Nerd Font aun no instalada, fallback: descarga directa de GitHub..."
            try {
                $fontTmp = Join-Path $env:TEMP "vorterm-nerdfont-$PID"
                $zipPath = Join-Path $fontTmp 'JetBrainsMono.zip'
                New-Item -ItemType Directory -Path $fontTmp -Force | Out-Null
                $url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
                Expand-Archive -Path $zipPath -DestinationPath $fontTmp -Force

                $userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
                New-Item -ItemType Directory -Path $userFonts -Force | Out-Null
                $reg = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
                if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }

                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                $installed = 0
                foreach ($ttf in (Get-ChildItem $fontTmp -Filter '*.ttf' -File)) {
                    $dest = Join-Path $userFonts $ttf.Name
                    Copy-Item $ttf.FullName $dest -Force
                    # Nombre de familia real del TTF para el valor de registro
                    $fam = $null
                    try {
                        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
                        $pfc.AddFontFile($dest)
                        $fam = $pfc.Families[0].Name
                        $pfc.Dispose()
                    } catch {}
                    if (-not $fam) { $fam = [IO.Path]::GetFileNameWithoutExtension($ttf.Name) }
                    New-ItemProperty -Path $reg -Name "$fam (TrueType)" -Value $dest `
                                     -PropertyType String -Force | Out-Null
                    $installed++
                }
                Remove-Item $fontTmp -Recurse -Force -ErrorAction SilentlyContinue
                if ($installed -gt 0) {
                    # Notificar cambio de fuentes a las apps (WM_FONTCHANGE)
                    try {
                        Add-Type -Namespace Vorterm -Name FontMsg -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, System.IntPtr lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@ -ErrorAction SilentlyContinue
                        $r = [UIntPtr]::Zero
                        [void][Vorterm.FontMsg]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)
                    } catch {}
                    Write-Log "  [OK] Nerd Font instalada por usuario ($installed ficheros TTF)"
                } else {
                    Write-Log "  [!!] Font fallback: zip sin TTFs"
                    $script:failures += 'font'
                }
            } catch {
                Write-Log "  [!!] Font fallback: $($_.Exception.Message)"
                $script:failures += 'font'
            }
        }

        # ---- WSL (separate from winget, uses wsl --install) ---
        if ($opts.WSL) {
            Set-Status 'WSL' 58
            try {
                $wslList = & wsl.exe --list --quiet 2>$null
                $hasDistro = ($LASTEXITCODE -eq 0) -and
                             ($wslList | Where-Object { $_ -and $_.Trim() } | Measure-Object).Count -gt 0
            } catch { $hasDistro = $false }

            if ($hasDistro) {
                Write-Log "  [OK] WSL already installed with distro"
            } elseif ($DRY) {
                Write-Log "  [DRY] wsl --install --no-launch"
            } else {
                Write-Log "  [..] installing WSL + default distro (Ubuntu, no-launch)..."
                try {
                    $wslProc = Start-Process wsl.exe -ArgumentList '--install','--no-launch' `
                               -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
                    if ($wslProc.ExitCode -eq 0) {
                        Write-Log "  [OK] WSL installed. Reboot may be required to finish setup."
                    } else {
                        Write-Log "  [!!] WSL install exit 0x$('{0:X8}' -f $wslProc.ExitCode)"
                        $script:failures += 'WSL'
                    }
                } catch {
                    Write-Log "  [!!] WSL: $($_.Exception.Message)"
                    $script:failures += 'WSL'
                }
            }
        }

        # Refresh PATH + re-locate pwsh
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        if (-not $pwshExe) { $pwshExe = Find-Pwsh }

        # ---- PS modules ----------------------------------
        Set-Status 'Modules' 60

        # Save-Module to PS7 path explicitly. Install-Module under PS5.1 host
        # would land in Documents\WindowsPowerShell\Modules which PS7 ignores.
        function Install-PSMod {
            param([string]$Name, [string]$Version)
            $ps7Mod = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules'

            try {
                $modDir = Join-Path $ps7Mod $Name
                $hasManifest = $false
                if (Test-Path $modDir) {
                    $hasManifest = [bool](Get-ChildItem $modDir -Recurse -Filter "$Name.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1)
                }
                if ($hasManifest) {
                    Write-Log "  [OK] $Name already present"
                    return
                }
                if ($DRY) {
                    Write-Log "  [DRY] Save-Module $Name $Version -> $ps7Mod"
                    return
                }
                if (-not (Test-Path $ps7Mod)) { New-Item -ItemType Directory -Path $ps7Mod -Force | Out-Null }
                if (Test-Path $modDir) {
                    Write-Log "  [..] $Name dir empty/corrupt, re-installing"
                    Remove-Item $modDir -Recurse -Force -ErrorAction SilentlyContinue
                }

                Write-Log ("  [..] {0} {1} -> {2}" -f $Name,$Version,$ps7Mod)
                $verArg = if ($Version) { "-RequiredVersion '$Version'" } else { '' }
                $cmd = "Save-Module -Name '$Name' -Path '$ps7Mod' -Force -ErrorAction Stop $verArg"
                if ($pwshExe) {
                    $out = & $pwshExe -NoProfile -Command $cmd 2>&1 | Out-String
                    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                        throw "pwsh Save-Module failed: $out"
                    }
                } else {
                    $saveArgs = @{
                        Name        = $Name
                        Path        = $ps7Mod
                        Force       = $true
                        ErrorAction = 'Stop'
                    }
                    if ($Version) { $saveArgs.RequiredVersion = $Version }
                    Save-Module @saveArgs
                }
                Write-Log "  [OK] $Name installed"
            } catch {
                Write-Log "  [!!] ${Name}: $($_.Exception.Message)"
                $script:failures += $Name
            }
        }

        $modIdx = 0
        $modList = @()
        if ($opts.PSRL)    { $modList += ,@{ N='PSReadLine';     V='2.3.6' } }
        if ($opts.Icons)   { $modList += ,@{ N='Terminal-Icons'; V=$null } }
        if ($opts.PoshGit) { $modList += ,@{ N='posh-git';       V=$null } }
        foreach ($m in $modList) {
            $modIdx++
            Set-Status "Modules ($modIdx/$($modList.Count))" (60 + [int](12 * $modIdx / [Math]::Max(1,$modList.Count)))
            Install-PSMod -Name $m.N -Version $m.V
        }

        # ---- Detect actual Nerd Font name ----------------
        # Windows Terminal usa DirectWrite. JetBrainsMono Nerd Font v3 tiene 2 nombres
        # en la tabla "name" del TTF:
        #   - name ID 1  (GDI family):           "JetBrainsMono NFM" (lo que enumera GDI+)
        #   - name ID 16 (typographic / DWrite): "JetBrainsMono Nerd Font Mono" (lo que WT espera)
        # Si escribimos el GDI family, WT muestra warning "no se puede encontrar la fuente"
        # y cae al fallback. Solucion: mapear GDI family -> typographic family.
        Set-Status 'Font detect' 74
        function Get-InstalledNerdFont {
            try { Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch {}
            $gdi = @()
            try {
                $gdi = [System.Drawing.Text.InstalledFontCollection]::new().Families.Name
            } catch {
                Write-Log "  [!!] GDI+ font enum failed: $($_.Exception.Message)"
            }

            # Mapping GDI family -> typographic (DirectWrite) family.
            # Nerd Font v3 convention: NFM=Mono, NFP=Propo, NF=full.
            # Prioridad NF (familia completa) primero: es la cara que usa el perfil
            # de referencia "PowerShell Main" (JetBrainsMono Nerd Font).
            $gdiToTypo = [ordered]@{
                'JetBrainsMono NF'     = 'JetBrainsMono Nerd Font'
                'JetBrainsMonoNL NF'   = 'JetBrainsMonoNL Nerd Font'
                'JetBrainsMono NFM'    = 'JetBrainsMono Nerd Font Mono'
                'JetBrainsMonoNL NFM'  = 'JetBrainsMonoNL Nerd Font Mono'
                'JetBrainsMono NFP'    = 'JetBrainsMono Nerd Font Propo'
                'JetBrainsMonoNL NFP'  = 'JetBrainsMonoNL Nerd Font Propo'
                'CaskaydiaCove NF'     = 'CaskaydiaCove Nerd Font'
                'CaskaydiaCove NFM'    = 'CaskaydiaCove Nerd Font Mono'
                'CaskaydiaMono NF'     = 'CaskaydiaMono Nerd Font'
                'FiraCode NF'          = 'FiraCode Nerd Font'
                'FiraCode NFM'         = 'FiraCode Nerd Font Mono'
                'Hack NF'              = 'Hack Nerd Font'
                'Hack NFM'             = 'Hack Nerd Font Mono'
            }

            # Prioridad: NF > Mono > Propo. Iterar mapping en orden.
            foreach ($gdiName in $gdiToTypo.Keys) {
                if ($gdi -contains $gdiName) {
                    $typo = $gdiToTypo[$gdiName]
                    Write-Log "  [OK] GDI '$gdiName' -> DWrite typographic '$typo'"
                    return $typo
                }
            }

            # Algunas instalaciones (Nerd Font v2 o variantes especiales) ya exponen
            # el typographic name como GDI family. Probar match directo.
            $directPriority = @(
                'JetBrainsMono Nerd Font',
                'JetBrainsMonoNL Nerd Font',
                'JetBrainsMono Nerd Font Mono',
                'JetBrainsMonoNL Nerd Font Mono',
                'JetBrainsMono Nerd Font Propo',
                'CaskaydiaCove Nerd Font',
                'FiraCode Nerd Font',
                'Hack Nerd Font'
            )
            foreach ($cand in $directPriority) {
                if ($gdi -contains $cand) { return $cand }
            }

            # Fallback generico: cualquier "Nerd Font Mono" en GDI+
            $hit = $gdi | Where-Object { $_ -match '(?i)Nerd\s+Font\s+Mono$' } | Select-Object -First 1
            if ($hit) { return $hit }
            $hit = $gdi | Where-Object { $_ -match '(?i)Nerd\s+Font' } | Select-Object -First 1
            if ($hit) { return $hit }

            Write-Log "  [!!] No Nerd Font detected. Falling back to default DWrite name."
            return 'JetBrainsMono Nerd Font'
        }
        $nerdFontFace = Get-InstalledNerdFont
        Write-Log "  [OK] detected font face (DWrite typographic): '$nerdFontFace'"

        # ---- Prompt theme (Mainthema, local, sin internet) ----
        Set-Status 'Theme' 76
        $userThemes = Join-Path $env:USERPROFILE '.poshthemes'
        $userTheme  = Join-Path $userThemes $opts.ThemeFile
        try {
            $srcContent = if ($opts.ThemeSrc -and (Test-Path $opts.ThemeSrc)) {
                Get-Content $opts.ThemeSrc -Raw -Encoding UTF8
            } else {
                $opts.ThemeJson
            }
            $needWrite = $true
            if (Test-Path $userTheme) {
                $cur = Get-Content $userTheme -Raw -Encoding UTF8
                if ($cur -eq $srcContent) {
                    Write-Log "  [OK] theme already at $userTheme"
                    $needWrite = $false
                }
            }
            if ($needWrite -and $DRY) {
                Write-Log "  [DRY] escribiria theme: $userTheme"
            } elseif ($needWrite) {
                if (-not (Test-Path $userThemes)) {
                    New-Item -ItemType Directory -Path $userThemes -Force | Out-Null
                }
                if (Test-Path $userTheme) {
                    $bk = "$userTheme.bak-$(Get-Date -Format yyyyMMddHHmmss)"
                    Copy-Item $userTheme $bk -Force
                    Write-Log "  [..] backup theme: $bk"
                }
                [System.IO.File]::WriteAllText($userTheme, $srcContent, (New-Object System.Text.UTF8Encoding $false))
                Write-Log "  [OK] theme written: $userTheme"
            }
        } catch {
            Write-Log "  [!!] theme: $($_.Exception.Message)"
            $script:failures += 'theme'
        }

        # Setear POSH_THEMES_PATH user env si esta vacio
        if (-not [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH','User')) {
            if ($DRY) {
                Write-Log "  [DRY] POSH_THEMES_PATH (User) -> $userThemes"
            } else {
                [Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $userThemes, 'User')
                Write-Log "  [OK] POSH_THEMES_PATH (User) -> $userThemes"
            }
        }

        # ---- PowerShell profile --------------------------
        if ($opts.WriteProfile) {
            Set-Status 'Profile' 80

            $ps7Dir  = Join-Path $env:USERPROFILE 'Documents\PowerShell'
            $ps7Path = Join-Path $ps7Dir 'Microsoft.PowerShell_profile.ps1'
            $ps5Dir  = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
            $ps5Path = Join-Path $ps5Dir 'Microsoft.PowerShell_profile.ps1'

            $escapedPath  = $opts.WorkDir -replace "'", "''"
            $themeLeaf    = $opts.ThemeFile

            # Perfil unico para PS5.1 y PS7 con guards por version:
            #  - PSReadLine Prediction* solo si PSReadLine >= 2.2 (PS5.1 trae 2.0.0
            #    y "parametro no encontrado" NO se suprime con -ErrorAction).
            #  - oh-my-posh init cacheado + try/catch -> si falla, prompt fallback.
            $profileContent = @"
# === Generated by Vorterm 7.1 - visual / terminal config ======

# --- Extra PATH (developer tools when present) ----------------
`$_pathAdds = 'C:\Program Files\Git\bin;C:\Program Files\Git\cmd;C:\Program Files\nodejs'
if (`$env:Path -notlike "*Git\cmd*") { `$env:Path = `$env:Path + ';' + `$_pathAdds }

# --- oh-my-posh (cached init, evita spawn de oh-my-posh.exe en cada arranque) -
`$script:_ompActive = `$false
`$_ompExe = "`$env:LOCALAPPDATA\Microsoft\WindowsApps\oh-my-posh.exe"
if (-not (Test-Path `$_ompExe)) { `$_ompExe = "`$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" }
if (Test-Path `$_ompExe) {
    try {
        `$_ompTheme = "`$env:USERPROFILE\.poshthemes\$themeLeaf"
        if (-not (Test-Path `$_ompTheme) -and `$env:POSH_THEMES_PATH) {
            `$_ompTheme = Join-Path `$env:POSH_THEMES_PATH '$themeLeaf'
        }
        `$_themeHash = [BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(`$_ompTheme))).Replace('-','').Substring(0,8)
        `$_ompCache  = "`$env:LOCALAPPDATA\Vorterm\omp-init-`$_themeHash.ps1"
        `$_cacheDir = Split-Path `$_ompCache
        if (-not (Test-Path `$_cacheDir)) { New-Item -ItemType Directory -Path `$_cacheDir -Force | Out-Null }
        `$_themeMtime = if (Test-Path `$_ompTheme) { (Get-Item `$_ompTheme).LastWriteTimeUtc.Ticks } else { 0 }
        `$_exeMtime   = (Get-Item `$_ompExe).LastWriteTimeUtc.Ticks
        `$_cacheValid = (Test-Path `$_ompCache) -and
                       ((Get-Item `$_ompCache).Length -gt 0) -and
                       ((Get-Item `$_ompCache).LastWriteTimeUtc.Ticks -gt [Math]::Max(`$_themeMtime,`$_exeMtime))
        if (-not `$_cacheValid) {
            if (Test-Path `$_ompTheme) {
                & `$_ompExe init pwsh --config `$_ompTheme | Out-File -FilePath `$_ompCache -Encoding utf8
            } else {
                & `$_ompExe init pwsh | Out-File -FilePath `$_ompCache -Encoding utf8
            }
        }
        if ((Get-Item `$_ompCache).Length -gt 0) {
            . `$_ompCache
            `$script:_ompActive = `$true
        }
    } catch {
        `$script:_ompActive = `$false
    }
}

# --- PSReadLine: import + config inmediato (necesario para tipear) -----------
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally -ErrorAction SilentlyContinue
    Set-PSReadLineOption -MaximumHistoryCount 20000          -ErrorAction SilentlyContinue
    Set-PSReadLineOption -BellStyle None                     -ErrorAction SilentlyContinue
    Set-PSReadLineOption -EditMode Windows                   -ErrorAction SilentlyContinue

    # Prediction: solo PSReadLine >= 2.2 (PS5.1 trae 2.0.0; el error de
    # parametro desconocido NO se suprime con -ErrorAction)
    if ((Get-Module PSReadLine).Version -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource History     -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    }

    Set-PSReadLineKeyHandler -Key Tab               -Function MenuComplete           -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+r            -Function ReverseSearchHistory   -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow           -Function HistorySearchBackward  -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow         -Function HistorySearchForward   -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow   -Function ForwardWord            -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow    -Function BackwardWord           -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace    -Function BackwardKillWord       -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Ctrl+Delete       -Function KillWord               -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Home              -Function BeginningOfLine        -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key End               -Function EndOfLine              -ErrorAction SilentlyContinue
}

# --- Modulos pesados: lazy load tras el primer prompt (no bloquea arranque) --
# posh-git/Terminal-Icons cuestan ~550ms juntos. Defer via OnIdle ejecuta en
# background despues del primer prompt, terminal aparece al usuario sin esperar.
`$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module posh-git       -ErrorAction SilentlyContinue
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# --- Aliases --------------------------------------------------
Set-Alias ll    Get-ChildItem
Set-Alias g     git
Set-Alias grep  Select-String
Set-Alias which Get-Command

function touch {
    param([Parameter(Mandatory)][string]`$Path)
    if (Test-Path `$Path) { (Get-Item `$Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path `$Path | Out-Null }
}

# --- Convenience functions ------------------------------------
function Open-Profile { notepad `$PROFILE }
Set-Alias profile Open-Profile

function SysInfo {
    Get-CimInstance Win32_OperatingSystem |
        Select-Object Caption, Version, BuildNumber, OSArchitecture |
        Format-List
}

function Update-Modules {
    Get-InstalledModule | ForEach-Object { Update-Module `$_.Name -Force }
}

# --- HTML / web helpers ---------------------------------------
function open {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments=`$true)] `$Rest)
    `$target = (`$Rest -join ' ').Trim()
    if (-not `$target) { `$target = '.' }
    Invoke-Item `$target
}

function html {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]`$Path)
    if (`$Path -match '^https?://') {
        Start-Process `$Path
    } elseif (Test-Path `$Path) {
        Start-Process (Resolve-Path `$Path).Path
    } else {
        Write-Error "Not a file or URL: `$Path"
    }
}

function serve {
    [CmdletBinding()]
    param([int]`$Port = 8000, [string]`$Path = '.')
    `$listener = [System.Net.HttpListener]::new()
    `$prefix = "http://localhost:`$Port/"
    `$listener.Prefixes.Add(`$prefix)
    `$root = (Resolve-Path `$Path).Path
    try {
        `$listener.Start()
        Write-Host "serving `$root at `$prefix  (Ctrl+C to stop)" -ForegroundColor Cyan
        while (`$listener.IsListening) {
            `$ctx = `$listener.GetContext()
            `$rel = [Uri]::UnescapeDataString(`$ctx.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace(`$rel)) { `$rel = 'index.html' }
            `$file = Join-Path `$root `$rel
            if (Test-Path `$file -PathType Leaf) {
                `$bytes = [System.IO.File]::ReadAllBytes(`$file)
                `$ext = [System.IO.Path]::GetExtension(`$file).ToLower()
                `$mime = switch (`$ext) {
                    '.html' {'text/html'}; '.htm' {'text/html'}
                    '.css'  {'text/css'};  '.js'  {'application/javascript'}
                    '.json' {'application/json'}
                    '.png'  {'image/png'}; '.jpg' {'image/jpeg'}; '.jpeg' {'image/jpeg'}
                    '.svg'  {'image/svg+xml'}; '.ico' {'image/x-icon'}
                    default {'application/octet-stream'}
                }
                `$ctx.Response.ContentType = `$mime
                `$ctx.Response.OutputStream.Write(`$bytes,0,`$bytes.Length)
            } else {
                `$ctx.Response.StatusCode = 404
                `$msg = [Text.Encoding]::UTF8.GetBytes("404 not found: `$rel")
                `$ctx.Response.OutputStream.Write(`$msg,0,`$msg.Length)
            }
            `$ctx.Response.OutputStream.Close()
        }
    } finally { `$listener.Stop(); `$listener.Close() }
}

# --- Elevation helper -----------------------------------------
function sudo {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments=`$true)] `$Rest)
    if (-not `$Rest -or `$Rest.Count -eq 0) {
        Start-Process pwsh -Verb RunAs
    } else {
        `$cmd = `$Rest -join ' '
        Start-Process pwsh -ArgumentList @('-NoExit','-Command',`$cmd) -Verb RunAs
    }
}

# --- Fallback prompt (only if oh-my-posh not active) ----------
if (-not `$script:_ompActive) {
    `$script:_hasGit = [bool](Get-Command git.exe -ErrorAction SilentlyContinue)
    function prompt {
        `$path = (Get-Location).Path
        `$branch = ''
        if (`$script:_hasGit) {
            `$b = git branch --show-current 2>`$null
            if (`$b) { `$branch = "  [`$b]" }
        }
        `$adminTag = ''
        if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            `$adminTag = ' (admin)'
        }
        Write-Host "[`$((Get-Date).ToString('HH:mm'))]`$adminTag `$path`$branch > " -ForegroundColor Cyan -NoNewline
        return ' '
    }
}

# --- Initial directory ----------------------------------------
if (-not `$global:__VortermStarted) {
    Set-Location '$escapedPath'
    `$global:__VortermStarted = `$true
    Clear-Host
}
"@

            # Validar sintaxis ANTES de escribir (nunca dejar un perfil roto)
            $parseErrors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($profileContent, [ref]$null, [ref]$parseErrors)
            if ($parseErrors -and $parseErrors.Count -gt 0) {
                Write-Log "  [!!] perfil generado con errores de sintaxis, NO se escribe:"
                foreach ($pe in $parseErrors) { Write-Log "       $($pe.Message)" }
                $script:failures += 'profile-syntax'
            } elseif ($DRY) {
                Write-Log "  [DRY] sintaxis perfil OK. Escribiria:"
                Write-Log "  [DRY]   $ps7Path"
                Write-Log "  [DRY]   $ps5Path"
            } else {
                foreach ($d in @($ps7Dir,$ps5Dir)) {
                    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
                }
                foreach ($t in @(@{P=$ps7Path;T='PS7'}, @{P=$ps5Path;T='PS5.1'})) {
                    try {
                        if (Test-Path $t.P) {
                            $bk = "$($t.P).bak-$(Get-Date -Format yyyyMMddHHmmss)"
                            Copy-Item $t.P $bk -Force
                            Write-Log "  [..] backup $($t.T): $bk"
                        }
                        [System.IO.File]::WriteAllText($t.P, $profileContent, (New-Object System.Text.UTF8Encoding $true))
                        Write-Log "  [OK] profile $($t.T): $($t.P)"
                    } catch {
                        Write-Log "  [!!] profile $($t.T): $($_.Exception.Message)"
                        $script:failures += "profile-$($t.T)"
                    }
                }
            }
        }

        # ---- Windows Terminal config ---------------------
        if ($opts.WTConfig) {
            Set-Status 'Windows Terminal config' 88

            $wtCandidates = @(
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
            ) | Where-Object { Test-Path $_ }

            if (-not $wtCandidates) {
                Write-Log "  [!!] Windows Terminal settings.json not found (open WT once to generate it)"
            } else {
                $ps7Guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
                $ps5Guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'

                # WT settings.json es JSONC: comentarios // /* */ Y comas finales.
                # ConvertFrom-Json (PS5.1) revienta con ambos. Limpiar los dos
                # preservando strings.
                function Remove-JsonComments {
                    param([string]$Text)
                    $sb = [System.Text.StringBuilder]::new()
                    $inString = $false; $escape = $false
                    $i = 0; $len = $Text.Length
                    while ($i -lt $len) {
                        $c = $Text[$i]
                        if ($inString) {
                            [void]$sb.Append($c)
                            if ($escape)        { $escape = $false }
                            elseif ($c -eq '\') { $escape = $true }
                            elseif ($c -eq '"') { $inString = $false }
                            $i++
                        } else {
                            if ($c -eq '"') {
                                $inString = $true; [void]$sb.Append($c); $i++
                            } elseif ($c -eq '/' -and $i+1 -lt $len -and $Text[$i+1] -eq '/') {
                                while ($i -lt $len -and $Text[$i] -ne "`n") { $i++ }
                            } elseif ($c -eq '/' -and $i+1 -lt $len -and $Text[$i+1] -eq '*') {
                                $i += 2
                                while ($i+1 -lt $len -and -not ($Text[$i] -eq '*' -and $Text[$i+1] -eq '/')) { $i++ }
                                $i += 2
                            } elseif ($c -eq '}' -or $c -eq ']') {
                                # trailing comma: quitar la coma colgante previa
                                $j = $sb.Length - 1
                                while ($j -ge 0 -and [char]::IsWhiteSpace($sb[$j])) { $j-- }
                                if ($j -ge 0 -and $sb[$j] -eq ',') { [void]$sb.Remove($j, 1) }
                                [void]$sb.Append($c); $i++
                            } else {
                                [void]$sb.Append($c); $i++
                            }
                        }
                    }
                    $sb.ToString()
                }

                foreach ($wtJson in $wtCandidates) {
                    try {
                        $raw   = Get-Content $wtJson -Raw -Encoding UTF8
                        $clean = Remove-JsonComments $raw
                        $json  = $clean | ConvertFrom-Json

                        if ($DRY) {
                            Write-Log "  [DRY] parse OK: $wtJson"
                            Write-Log "  [DRY]   font -> '$nerdFontFace', defaultProfile -> PS7, startingDirectory -> $($opts.WorkDir)"
                            if ($opts.Elevate) { Write-Log "  [DRY]   elevate -> true (UAC por pestaña)" }
                            continue
                        }

                        $bk = "$wtJson.bak-$(Get-Date -Format yyyyMMddHHmmss)"
                        Copy-Item $wtJson $bk -Force
                        Write-Log "  [..] backup WT: $bk"

                        function Set-Prop {
                            param($obj, [string]$name, $value)
                            if ($obj.PSObject.Properties.Name -contains $name) {
                                $obj.$name = $value
                            } else {
                                $obj | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force
                            }
                        }

                        # --- defaults.font + defaults.colorScheme -
                        if (-not $json.profiles) {
                            Set-Prop $json 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() })
                        }
                        if (-not $json.profiles.defaults) {
                            Set-Prop $json.profiles 'defaults' ([pscustomobject]@{})
                        }
                        if (-not $json.profiles.defaults.font) {
                            Set-Prop $json.profiles.defaults 'font' ([pscustomobject]@{ face = $nerdFontFace; size = 11 })
                        } else {
                            Set-Prop $json.profiles.defaults.font 'face' $nerdFontFace
                            if (-not ($json.profiles.defaults.font.PSObject.Properties.Name -contains 'size')) {
                                Set-Prop $json.profiles.defaults.font 'size' 11
                            }
                        }

                        # --- per-profile patch -----------------
                        $patched = $false
                        if ($json.profiles.list) {
                            foreach ($prof in $json.profiles.list) {
                                if ($prof.guid -eq $ps5Guid) { continue }
                                $isPwsh = ($prof.guid -eq $ps7Guid) -or
                                          ($prof.commandline -match '(?i)\bpwsh(\.exe)?\b') -or
                                          ($prof.name -match '(?i)PowerShell' -and $prof.name -notmatch '(?i)Windows PowerShell')
                                if ($isPwsh) {
                                    Set-Prop $prof 'commandline' 'pwsh.exe -NoLogo -NoProfileLoadTime'
                                    Set-Prop $prof 'startingDirectory' $opts.WorkDir
                                    if ($opts.Elevate) {
                                        Set-Prop $prof 'elevate' $true
                                    }
                                    # Mismo bloque font que el equipo de referencia:
                                    # face + size 14 + weight normal + glyphs integrados a color
                                    if (-not $prof.font) {
                                        Set-Prop $prof 'font' ([pscustomobject]@{
                                            face = $nerdFontFace; size = 14; weight = 'normal'
                                            builtinGlyphs = $true; colorGlyphs = $true })
                                    } else {
                                        Set-Prop $prof.font 'face' $nerdFontFace
                                        Set-Prop $prof.font 'size' 14
                                        Set-Prop $prof.font 'weight' 'normal'
                                        Set-Prop $prof.font 'builtinGlyphs' $true
                                        Set-Prop $prof.font 'colorGlyphs' $true
                                        foreach ($k in 'cellHeight','cellWidth') {
                                            if ($prof.font.PSObject.Properties.Name -contains $k) {
                                                $prof.font.PSObject.Properties.Remove($k)
                                            }
                                        }
                                    }
                                    Write-Log "  [OK] WT profile patched: $($prof.name)"
                                    $patched = $true
                                }
                            }
                        }

                        if (-not $patched -and $pwshExe) {
                            # Add a PowerShell 7 entry if missing
                            $newProf = [pscustomobject]@{
                                guid              = $ps7Guid
                                name              = 'PowerShell'
                                commandline       = 'pwsh.exe -NoLogo -NoProfileLoadTime'
                                startingDirectory = $opts.WorkDir
                                hidden            = $false
                                font              = [pscustomobject]@{
                                    face = $nerdFontFace; size = 14; weight = 'normal'
                                    builtinGlyphs = $true; colorGlyphs = $true }
                            }
                            if ($opts.Elevate) { Set-Prop $newProf 'elevate' $true }
                            if (-not $json.profiles.list) { Set-Prop $json.profiles 'list' @() }
                            $json.profiles.list = @($newProf) + @($json.profiles.list)
                            Write-Log "  [OK] WT profile added: PowerShell 7"
                        }

                        # --- defaultProfile -> PS7 -------------
                        if ($pwshExe) {
                            Set-Prop $json 'defaultProfile' $ps7Guid
                            Write-Log "  [OK] WT defaultProfile -> PowerShell 7"
                        }

                        # --- write back ------------------------
                        $out = $json | ConvertTo-Json -Depth 64
                        [System.IO.File]::WriteAllText($wtJson, $out, (New-Object System.Text.UTF8Encoding $false))
                        Write-Log "  [OK] WT settings written: $wtJson"
                    } catch {
                        Write-Log "  [!!] WT cfg: $($_.Exception.Message)"
                        $script:failures += 'wt-config'
                    }
                }
            }
        }

        # ---- Verify --------------------------------------
        if ($opts.Verify) {
            Set-Status 'Verify' 94

            # Smoke test: arrancar pwsh CON el perfil recien escrito y capturar
            # errores. Esto caza exactamente "abro la terminal y saltan errores".
            if ($pwshExe -and $opts.WriteProfile -and -not $DRY) {
                try {
                    Write-Log "  [..] smoke test: cargando perfil en pwsh..."
                    $smokeRaw = & $pwshExe -NoLogo -Command '"__SMOKE_END__"' 2>&1
                    $smokeErr = @($smokeRaw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
                    if ($smokeErr.Count -gt 0) {
                        Write-Log "  [!!] el perfil emite errores al arrancar:"
                        foreach ($e in ($smokeErr | Select-Object -First 5)) { Write-Log "       $e" }
                        $script:failures += 'profile-smoke'
                    } else {
                        Write-Log "  [OK] perfil carga sin errores en PS7"
                    }
                } catch {
                    Write-Log "  [!!] smoke test: $($_.Exception.Message)"
                }
            } elseif ($DRY) {
                Write-Log "  [DRY] smoke test omitido (no se escribio perfil)"
            }

            if ($pwshExe -and $opts.Icons -and -not $DRY) {
                try {
                    $verifyCmd = 'Import-Module Terminal-Icons -ErrorAction Stop; if (Get-Module Terminal-Icons) { "OK" } else { "MISSING" }'
                    $verifyOut = & $pwshExe -NoProfile -NoLogo -Command $verifyCmd 2>&1
                    if ($verifyOut -match 'OK') {
                        Write-Log "  [OK] Terminal-Icons loads cleanly in PS7"
                    } else {
                        Write-Log "  [!!] Terminal-Icons did not load: $verifyOut"
                        $script:failures += 'verify-Terminal-Icons'
                    }
                } catch {
                    Write-Log "  [!!] verify Terminal-Icons: $($_.Exception.Message)"
                }
            }

            if ($opts.OMP) {
                $ompExe = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source
                if (-not $ompExe) {
                    $candidate = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe"
                    if (Test-Path $candidate) { $ompExe = $candidate }
                }
                if ($ompExe) {
                    Write-Log "  [OK] oh-my-posh: $ompExe"
                    if (Test-Path $userTheme) {
                        Write-Log "  [OK] theme present: $userTheme"
                    } elseif ($DRY) {
                        Write-Log "  [DRY] theme se escribiria en: $userTheme"
                    } else {
                        Write-Log "  [!!] theme missing: $userTheme"
                        $script:failures += 'omp-theme'
                    }
                } else {
                    Write-Log "  [!!] oh-my-posh.exe not found"
                    if (-not $DRY) { $script:failures += 'omp-bin' }
                }
            }

            # JetBrainsMono Nerd Font variants: "Nerd Font", "NF", "NFM", "NFP", "NL".
            # Solo "Nerd Font" full contiene literal "Nerd"; las demas siglas no.
            $nfRx = '(?i)(Nerd|\bN[FL][MP]?\b|JetBrainsMono\s*N[FL])'
            $hasFont = $false
            $detectedAs = ''
            foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                              'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
                if (Test-Path $hive) {
                    $names = (Get-ItemProperty $hive).PSObject.Properties.Name |
                             Where-Object { $_ -notlike 'PS*' }
                    $hit = $names | Where-Object { $_ -match $nfRx } | Select-Object -First 1
                    if ($hit) { $hasFont = $true; $detectedAs = "registry: $hit"; break }
                }
            }
            if (-not $hasFont) {
                # Fallback: check Fonts folders directly (winget user install sometimes
                # drops files there before the registry refresh)
                $fontDirs = @("$env:WINDIR\Fonts",
                              (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'))
                foreach ($fd in $fontDirs) {
                    if (Test-Path $fd) {
                        $files = Get-ChildItem -Path (Join-Path $fd '*') -Include '*.ttf','*.otf' -File -ErrorAction SilentlyContinue |
                                 Select-Object -ExpandProperty Name
                        $hit = $files | Where-Object { $_ -match $nfRx } | Select-Object -First 1
                        if ($hit) { $hasFont = $true; $detectedAs = "file: $hit"; break }
                    }
                }
            }
            if ($hasFont) {
                Write-Log "  [OK] Nerd Font detected ($detectedAs)"
            } else {
                Write-Log "  [!!] No Nerd Font detected. ls icons will not render"
                if (-not $DRY) { $script:failures += 'nerd-font' }
            }
        }

        # ---- Done ----------------------------------------
        Set-Status $(if ($DRY) { 'Dry run done' } else { 'Done' }) 100
        $elapsed = (Get-Date) - $started
        Write-Log ""
        Write-Log "============================================================"
        if ($DRY) {
            Write-Log "  DRY RUN completado. Nada se ha modificado."
            if ($script:failures.Count -gt 0) {
                Write-Log "  Avisos: $($script:failures -join ', ')"
            }
        } elseif ($script:failures.Count -gt 0) {
            Write-Log "  Finished with warnings: $($script:failures -join ', ')"
        } else {
            Write-Log "  All green. System ready."
        }
        Write-Log ("  Elapsed: {0:N1}s" -f $elapsed.TotalSeconds)
        Write-Log "============================================================"
        Write-Log ""
        Write-Log "Reinicia Windows Terminal para cargar fuente + tema."
        if ($opts.Elevate) { Write-Log "Aviso: pestañas PS7 elevadas -> UAC por pestaña." }
        Write-Log "Glifos como cajas? WT Settings -> PowerShell -> Appearance -> Font -> Nerd Font."
        Write-Log "Helpers: html, open, serve, sudo, touch, profile, SysInfo, Update-Modules."

    } catch {
        # Excepcion no controlada: registrar SIEMPRE, no dejar la GUI colgada.
        Write-Log ""
        Write-Log "  [!!] ERROR FATAL: $($_.Exception.Message)"
        Write-Log "       $($_.ScriptStackTrace)"
        $script:failures += 'fatal'
        Set-Status 'Error' 100
    } finally {
        if (-not $sync.NoGui) {
            $sync.Window.Dispatcher.Invoke([action]{
                $sync.InstallBtn.IsEnabled = $true
                $sync.ResetBtn.IsEnabled   = $true
                $sync.PauseBtn.Visibility  = [System.Windows.Visibility]::Collapsed
                if ($script:failures -contains 'fatal') {
                    $sync.StatusText.Text = 'Error'
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::OrangeRed
                } elseif ($script:failures.Count) {
                    $sync.StatusText.Text = 'Warnings'
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::Goldenrod
                } else {
                    $sync.StatusText.Text = $(if ($opts.DryRun) { 'Dry run OK' } else { 'Ready' })
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::LightGreen
                }
            })
        }
    }
}

# =============================================================
#  RESET LOGIC (compartida)
# =============================================================
$ResetLogic = {

    function Write-Log {
        param([string]$Msg)
        if ($sync.NoGui) { Write-Host $Msg; return }
        $sync.Window.Dispatcher.Invoke([action]{
            $color = '#d9d9d9'
            if     ($Msg -match '\[OK\]')  { $color = '#fcee0a' }
            elseif ($Msg -match '\[!!\]')  { $color = '#ff2b4a' }
            elseif ($Msg -match '\[DRY\]') { $color = '#66d9ff' }
            elseif ($Msg -match '\[\.\.\]'){ $color = '#6a6c70' }
            elseif ($Msg -match '^\s*=+')  { $color = '#8a8104' }
            $run = New-Object System.Windows.Documents.Run($Msg)
            $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($color)
            [void]$sync.LogPara.Inlines.Add($run)
            [void]$sync.LogPara.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
            $sync.LogBox.ScrollToEnd()
        })
    }
    function Set-Status {
        param([string]$Text, [int]$Pct = -1)
        if ($sync.NoGui) { Write-Host ">> $Text" -ForegroundColor DarkYellow; return }
        $sync.Window.Dispatcher.Invoke([action]{
            $sync.StatusText.Text = $Text
            if ($Pct -ge 0) { $sync.Progress.Value = $Pct }
        })
    }

    function Remove-JsonComments {
        param([string]$Text)
        $sb = [System.Text.StringBuilder]::new()
        $inString = $false; $escape = $false
        $i = 0; $len = $Text.Length
        while ($i -lt $len) {
            $c = $Text[$i]
            if ($inString) {
                [void]$sb.Append($c)
                if ($escape)        { $escape = $false }
                elseif ($c -eq '\') { $escape = $true }
                elseif ($c -eq '"') { $inString = $false }
                $i++
            } else {
                if ($c -eq '"') { $inString = $true; [void]$sb.Append($c); $i++ }
                elseif ($c -eq '/' -and $i+1 -lt $len -and $Text[$i+1] -eq '/') {
                    while ($i -lt $len -and $Text[$i] -ne "`n") { $i++ }
                } elseif ($c -eq '/' -and $i+1 -lt $len -and $Text[$i+1] -eq '*') {
                    $i += 2
                    while ($i+1 -lt $len -and -not ($Text[$i] -eq '*' -and $Text[$i+1] -eq '/')) { $i++ }
                    $i += 2
                } elseif ($c -eq '}' -or $c -eq ']') {
                    $j = $sb.Length - 1
                    while ($j -ge 0 -and [char]::IsWhiteSpace($sb[$j])) { $j-- }
                    if ($j -ge 0 -and $sb[$j] -eq ',') { [void]$sb.Remove($j, 1) }
                    [void]$sb.Append($c); $i++
                } else {
                    [void]$sb.Append($c); $i++
                }
            }
        }
        $sb.ToString()
    }

    $started   = Get-Date
    $failures  = @()
    $stamp     = Get-Date -Format yyyyMMddHHmmss
    $DRY       = [bool]$opts.DryRun

    try {

        Write-Log "============================================================"
        Write-Log "  Vorterm deep reset  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
        if ($DRY) {
        Write-Log "  MODO DRY RUN - simulacion, no se modifica NADA"
        }
        Write-Log "============================================================"
        Write-Log ""

        # ---- 1. Profiles --------------------------------
        if ($opts.CleanProfile) {
            Set-Status 'Profiles' 8
            $userDocs = Join-Path $env:USERPROFILE 'Documents'
            $profileDirs = @(
                Join-Path $userDocs 'PowerShell',
                Join-Path $userDocs 'WindowsPowerShell'
            )
            $profileNames = @(
                'profile.ps1',
                'Microsoft.PowerShell_profile.ps1',
                'Microsoft.PowerShellISE_profile.ps1',
                'Microsoft.VSCode_profile.ps1'
            )
            foreach ($d in $profileDirs) {
                if (-not (Test-Path $d)) { continue }
                foreach ($n in $profileNames) {
                    $p = Join-Path $d $n
                    try {
                        $bks = Get-ChildItem -Path "$p.bak-*" -File -ErrorAction SilentlyContinue |
                               Sort-Object LastWriteTime -Descending
                        if ($bks -and $bks.Count -gt 0) {
                            if ($DRY) { Write-Log "  [DRY] restauraria $p desde $($bks[0].Name)"; continue }
                            Copy-Item $bks[0].FullName $p -Force
                            Write-Log "  [OK] restored $p"
                            Write-Log "       from: $($bks[0].Name)"
                        } elseif (Test-Path $p) {
                            if ($DRY) { Write-Log "  [DRY] moveria $p a .before-reset-$stamp"; continue }
                            $bk = "$p.before-reset-$stamp"
                            Copy-Item $p $bk -Force
                            Remove-Item $p -Force
                            Write-Log "  [OK] removed $p"
                            Write-Log "       safety copy: $bk"
                        }
                    } catch {
                        Write-Log "  [!!] $p : $($_.Exception.Message)"
                        $failures += "profile-$n"
                    }
                }
            }

            # OMP init cache generado por el perfil Vorterm
            $ompCacheDir = Join-Path $env:LOCALAPPDATA 'Vorterm'
            if (Test-Path $ompCacheDir) {
                if ($DRY) {
                    Write-Log "  [DRY] borraria cache OMP: $ompCacheDir"
                } else {
                    try {
                        Remove-Item $ompCacheDir -Recurse -Force -ErrorAction Stop
                        Write-Log "  [OK] removed OMP init cache: $ompCacheDir"
                    } catch {
                        Write-Log "  [!!] cache: $($_.Exception.Message)"
                    }
                }
            }
        }

        # ---- 2. PSReadLine history ----------------------
        if ($opts.CleanHistory) {
            Set-Status 'History' 25
            $hDir = Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine'
            if (Test-Path $hDir) {
                $hFiles = Get-ChildItem -Path $hDir -Filter '*_history.txt' -File -ErrorAction SilentlyContinue
                if (-not $hFiles) {
                    Write-Log "  [..] no history files in $hDir"
                } else {
                    foreach ($hf in $hFiles) {
                        try {
                            if ($DRY) { Write-Log "  [DRY] borraria $($hf.Name)"; continue }
                            Remove-Item $hf.FullName -Force
                            Write-Log "  [OK] cleared $($hf.Name)"
                        } catch {
                            Write-Log "  [!!] $($hf.Name) : $($_.Exception.Message)"
                            $failures += "history-$($hf.Name)"
                        }
                    }
                }
            } else {
                Write-Log "  [..] $hDir not present"
            }
            if (-not $DRY) {
                try {
                    Clear-History -ErrorAction SilentlyContinue
                    Write-Log "  [OK] in-session history cleared"
                } catch {}
            }
        }

        # ---- 3. Terminal/prompt modules -----------------
        if ($opts.CleanModules) {
            Set-Status 'Modules' 45

            $allowList = @(
                'PSReadLine','Terminal-Icons','posh-git','oh-my-posh',
                'PowerLine','PSColor','Get-ChildItemColor','GetChildItemColor',
                'Pansies','PoshColor','PSFzf','PSEverything','cd-extras','z',
                'PowerShellHumanizer','BurntToast','DockerCompletion','PSDirTagger',
                'WslInterop'
            )
            $blockPatterns = @(
                '^Az\.', '^AzureAD', '^AzureRM',
                '^Microsoft\.Graph', '^MSOnline',
                '^ExchangeOnlineManagement$', '^Exchange',
                '^MicrosoftTeams$', '^PnP\.', '^SharePoint',
                '^Microsoft\.PowerShell\.', '^PowerShellGet$', '^PackageManagement$',
                '^PSScriptAnalyzer$', '^Pester$', '^SqlServer$', '^dbatools$',
                '^Microsoft\.WSMan'
            )

            foreach ($name in $allowList) {
                $blocked = $false
                foreach ($pat in $blockPatterns) {
                    if ($name -match $pat) { $blocked = $true; break }
                }
                if ($blocked) { Write-Log "  [..] $name in blocklist - skipped"; continue }

                try {
                    $installed = Get-Module -ListAvailable -Name $name -ErrorAction SilentlyContinue
                    if (-not $installed) { continue }

                    if ($DRY) {
                        Write-Log "  [DRY] desinstalaria modulo: $name"
                        continue
                    }

                    Get-Module -Name $name -ErrorAction SilentlyContinue |
                        Remove-Module -Force -ErrorAction SilentlyContinue

                    try {
                        Uninstall-Module -Name $name -AllVersions -Force -ErrorAction Stop
                        Write-Log "  [OK] uninstalled $name (all versions)"
                    } catch {
                        # Some modules (like a system-wide PSReadLine bundled with Windows)
                        # cannot be Uninstall-Module'd. Try manual file removal as fallback.
                        $manualRemoved = $false
                        foreach ($m in $installed) {
                            $modBase = $m.ModuleBase
                            if ($modBase -and (Test-Path $modBase) -and ($modBase -like "$env:USERPROFILE*")) {
                                try {
                                    Remove-Item $modBase -Recurse -Force -ErrorAction Stop
                                    Write-Log "  [OK] removed $name $($m.Version) at $modBase"
                                    $manualRemoved = $true
                                } catch {
                                    Write-Log "  [!!] $name $($m.Version) at $modBase : $($_.Exception.Message)"
                                }
                            } else {
                                Write-Log "  [..] $name $($m.Version) at $modBase (system path, skipped)"
                            }
                        }
                        if (-not $manualRemoved) {
                            Write-Log "  [!!] uninstall $name : $($_.Exception.Message)"
                            $failures += "uninstall-$name"
                        }
                    }
                } catch {
                    Write-Log "  [!!] $name : $($_.Exception.Message)"
                    $failures += "module-$name"
                }
            }

            # oh-my-posh winget package
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                try {
                    $omp = winget list --id JanDeDobbeleer.OhMyPosh -e --accept-source-agreements 2>$null | Out-String
                    if ($omp -match 'JanDeDobbeleer\.OhMyPosh') {
                        if ($DRY) {
                            Write-Log "  [DRY] desinstalaria oh-my-posh (winget)"
                        } else {
                            Write-Log "  [..] uninstalling oh-my-posh (winget package)..."
                            winget uninstall --id JanDeDobbeleer.OhMyPosh -e --silent --disable-interactivity 2>&1 | Out-Null
                            Write-Log "  [OK] oh-my-posh winget package removed"
                        }
                    }
                } catch { Write-Log "  [..] winget oh-my-posh check skipped" }
            }
        }

        # ---- 4. Windows Terminal ------------------------
        if ($opts.CleanWT) {
            Set-Status 'Windows Terminal' 80
            $wtCandidates = @(
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
            ) | Where-Object { Test-Path $_ }

            if (-not $wtCandidates) {
                Write-Log "  [..] no Windows Terminal settings.json found"
            } else {
                $signature = 'pwsh.exe -NoLogo -NoProfileLoadTime'
                $ps7Guid   = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'

                foreach ($wt in $wtCandidates) {
                    try {
                        $bks = Get-ChildItem -Path "$wt.bak-*" -File -ErrorAction SilentlyContinue |
                               Sort-Object LastWriteTime -Descending

                        if ($bks -and $bks.Count -gt 0) {
                            if ($DRY) { Write-Log "  [DRY] restauraria $wt desde $($bks[0].Name)"; continue }
                            Copy-Item $bks[0].FullName $wt -Force
                            Write-Log "  [OK] restored $wt"
                            Write-Log "       from: $($bks[0].Name)"
                            continue
                        }

                        # No backup: strip Vorterm markers in-place
                        if ($DRY) { Write-Log "  [DRY] limpiaria claves Vorterm en $wt"; continue }
                        Write-Log "  [..] no backup for $wt, stripping Vorterm keys..."
                        $bk = "$wt.before-reset-$stamp"
                        Copy-Item $wt $bk -Force

                        $raw   = Get-Content $wt -Raw -Encoding UTF8
                        $clean = Remove-JsonComments $raw
                        $json  = $clean | ConvertFrom-Json

                        $changed = $false

                        if ($json.profiles -and $json.profiles.list) {
                            foreach ($prof in $json.profiles.list) {
                                $isPwsh = ($prof.guid -eq $ps7Guid) -or
                                          ($prof.commandline -eq $signature) -or
                                          ($prof.commandline -match 'NoProfileLoadTime')
                                if (-not $isPwsh) { continue }

                                foreach ($k in 'commandline','font','elevate','startingDirectory') {
                                    if ($prof.PSObject.Properties.Name -contains $k) {
                                        $prof.PSObject.Properties.Remove($k)
                                        $changed = $true
                                    }
                                }
                                Write-Log "  [OK] stripped keys from profile: $($prof.name)"
                            }
                        }

                        if ($json.profiles -and
                            $json.profiles.defaults -and
                            $json.profiles.defaults.font -and
                            $json.profiles.defaults.font.face -match '(?i)Nerd') {
                            $json.profiles.defaults.PSObject.Properties.Remove('font')
                            $changed = $true
                            Write-Log "  [OK] removed defaults.font (Nerd font marker)"
                        }

                        if ($changed) {
                            $out = $json | ConvertTo-Json -Depth 64
                            [System.IO.File]::WriteAllText($wt, $out, (New-Object System.Text.UTF8Encoding $false))
                            Write-Log "  [OK] saved cleaned $wt"
                            Write-Log "       safety copy: $bk"
                        } else {
                            Remove-Item $bk -Force
                            Write-Log "  [..] no Vorterm markers found, file unchanged"
                        }
                    } catch {
                        Write-Log "  [!!] $wt : $($_.Exception.Message)"
                        $failures += 'wt'
                    }
                }
            }
        }

        Set-Status $(if ($DRY) { 'Dry run done' } else { 'Done' }) 100
        $elapsed = (Get-Date) - $started
        Write-Log ""
        Write-Log "============================================================"
        if ($DRY) {
            Write-Log "  DRY RUN de reset completado. Nada se ha modificado."
        } elseif ($failures.Count) {
            Write-Log "  Reset finished with warnings: $($failures -join ', ')"
        } else {
            Write-Log "  Deep reset complete. Terminal back to clean state."
        }
        Write-Log ("  Elapsed: {0:N1}s" -f $elapsed.TotalSeconds)
        Write-Log "============================================================"
        Write-Log ""
        Write-Log "Untouched: PowerShell 7, Git, Windows Terminal, Nerd Font, Az/Graph/EXO modules, ~\.poshthemes."
        Write-Log "Open a new terminal window to see the clean state (current session keeps loaded modules in memory)."

    } catch {
        Write-Log ""
        Write-Log "  [!!] ERROR FATAL: $($_.Exception.Message)"
        Write-Log "       $($_.ScriptStackTrace)"
        $failures += 'fatal'
        Set-Status 'Error' 100
    } finally {
        if (-not $sync.NoGui) {
            $sync.Window.Dispatcher.Invoke([action]{
                $sync.InstallBtn.IsEnabled = $true
                $sync.ResetBtn.IsEnabled   = $true
                if ($failures -contains 'fatal') {
                    $sync.StatusText.Text = 'Error'
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::OrangeRed
                } elseif ($failures.Count) {
                    $sync.StatusText.Text = 'Warnings'
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::Goldenrod
                } else {
                    $sync.StatusText.Text = $(if ($opts.DryRun) { 'Dry run OK' } else { 'Reset done' })
                    $sync.StatusText.Foreground = [Windows.Media.Brushes]::LightGreen
                }
            })
        }
    }
}

# =============================================================
#  CONSOLE MODE (-NoGui): para pruebas y automatizacion
# =============================================================
if ($NoGui) {
    $sync = @{
        NoGui       = $true
        ActiveProcs = [System.Collections.ArrayList]::new()
        Paused      = $false
    }
    $opts = @{
        WorkDir      = Join-Path $env:USERPROFILE 'Documents'
        Pwsh         = $true
        Git          = $true
        WT           = $true
        Font         = $true
        OMP          = $true
        PSRL         = $true
        Icons        = $true
        PoshGit      = $true
        WriteProfile = $true
        WTConfig     = $true
        Elevate      = $false
        VSCode       = $false
        Neovim       = $false
        SevenZip     = $false
        GitHubDesktop = $false
        WSL          = $false
        Policy       = $true
        Verify       = $true
        DryRun       = [bool]$DryRun
        ThemeFile    = $script:ThemeFileName
        ThemeSrc     = $script:ThemeSrc
        ThemeJson    = $script:ThemeJson
    }
    & $InstallLogic
    return
}

# =============================================================
#  GUI MODE
# =============================================================

# ------ XAML ------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Vorterm 7.1"
        Height="940" Width="1700"
        MinHeight="560" MinWidth="980"
        WindowStartupLocation="CenterScreen"
        Background="#050506"
        FontFamily="Inter, Segoe UI"
        FontSize="16"
        Foreground="#e8e8e8"
        ResizeMode="CanResize">
  <Window.Resources>
    <SolidColorBrush x:Key="Bg"          Color="#050506"/>
    <SolidColorBrush x:Key="Surface"     Color="#0c0d0f"/>
    <SolidColorBrush x:Key="Surface2"    Color="#121316"/>
    <SolidColorBrush x:Key="Border1"     Color="#1f2024"/>
    <SolidColorBrush x:Key="BorderStrong" Color="#3a3b40"/>
    <SolidColorBrush x:Key="Text"        Color="#e8e8e8"/>
    <SolidColorBrush x:Key="Muted"       Color="#6a6c70"/>
    <SolidColorBrush x:Key="Dim"         Color="#2a2b2f"/>
    <SolidColorBrush x:Key="Gold"        Color="#fcee0a"/>
    <SolidColorBrush x:Key="GoldHi"      Color="#fff86b"/>
    <SolidColorBrush x:Key="GoldDim"     Color="#8a8104"/>
    <SolidColorBrush x:Key="GoldFaint"   Color="#3a3601"/>
    <SolidColorBrush x:Key="Danger"      Color="#e10024"/>
    <SolidColorBrush x:Key="Cyan"        Color="#66d9ff"/>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="#e8e8e8"/>
      <Setter Property="FontSize" Value="16"/>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#e8e8e8"/>
      <Setter Property="FontSize" Value="17"/>
      <Setter Property="Margin" Value="0,8,14,8"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="FontFamily" Value="Bahnschrift Light, Bahnschrift, Segoe UI Light"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>

    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="#121316"/>
      <Setter Property="Foreground" Value="#e8e8e8"/>
      <Setter Property="BorderBrush" Value="#3a3b40"/>
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#e8e8e8"/>
      <Setter Property="CaretBrush" Value="{StaticResource Gold}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderStrong}"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="Padding" Value="2,9"/>
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="16"/>
    </Style>

    <Style x:Key="GhostButton" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource Gold}"/>
      <Setter Property="BorderBrush" Value="{StaticResource GoldFaint}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="26,11"/>
      <Setter Property="FontWeight" Value="Normal"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Gold}"/>
                <Setter TargetName="bd" Property="Background" Value="#0c0d02"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1a1802"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WarningButton" TargetType="Button" BasedOn="{StaticResource GhostButton}">
      <Setter Property="Foreground" Value="{StaticResource Danger}"/>
      <Setter Property="BorderBrush" Value="#7a0015"/>
    </Style>

    <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource GhostButton}">
      <Setter Property="Foreground" Value="{StaticResource Gold}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Gold}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="42,11"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd"
                    Background="Transparent"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}">
              <Border.Effect>
                <DropShadowEffect x:Name="glow" Color="#fcee0a" BlurRadius="14" ShadowDepth="0" Opacity="0.7"/>
              </Border.Effect>
              <ContentPresenter HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource GoldHi}"/>
                <Setter TargetName="bd" Property="Background" Value="#0c0d02"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1a1802"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ProgressBar">
      <Setter Property="Background" Value="{StaticResource Dim}"/>
      <Setter Property="Foreground" Value="{StaticResource Gold}"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>

    <Style x:Key="RomanLabel" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Gold}"/>
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,0"/>
    </Style>

    <Style x:Key="SectionRule" TargetType="Border">
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource GoldFaint}"/>
      <Setter Property="HorizontalAlignment" Value="Stretch"/>
      <Setter Property="Margin" Value="0,8,0,14"/>
    </Style>

    <Style x:Key="PathLabel" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Gold}"/>
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Margin" Value="0,8,0,2"/>
    </Style>

    <Style x:Key="PathValue" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="JetBrains Mono, Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,0"/>
    </Style>

    <!-- Tron-style corner brackets (4 small L-shapes around content) -->
    <Style x:Key="CornerTL" TargetType="Border">
      <Setter Property="Width" Value="12"/>
      <Setter Property="Height" Value="12"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="BorderBrush" Value="{StaticResource Gold}"/>
      <Setter Property="BorderThickness" Value="1,1,0,0"/>
    </Style>
    <Style x:Key="CornerTR" TargetType="Border">
      <Setter Property="Width" Value="12"/>
      <Setter Property="Height" Value="12"/>
      <Setter Property="HorizontalAlignment" Value="Right"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="BorderBrush" Value="{StaticResource Gold}"/>
      <Setter Property="BorderThickness" Value="0,1,1,0"/>
    </Style>
    <Style x:Key="CornerBL" TargetType="Border">
      <Setter Property="Width" Value="12"/>
      <Setter Property="Height" Value="12"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="VerticalAlignment" Value="Bottom"/>
      <Setter Property="BorderBrush" Value="{StaticResource Gold}"/>
      <Setter Property="BorderThickness" Value="1,0,0,1"/>
    </Style>
    <Style x:Key="CornerBR" TargetType="Border">
      <Setter Property="Width" Value="12"/>
      <Setter Property="Height" Value="12"/>
      <Setter Property="HorizontalAlignment" Value="Right"/>
      <Setter Property="VerticalAlignment" Value="Bottom"/>
      <Setter Property="BorderBrush" Value="{StaticResource Gold}"/>
      <Setter Property="BorderThickness" Value="0,0,1,1"/>
    </Style>
    <!-- Custom dark/yellow ScrollBar -->
    <Style x:Key="VtScrollThumb" TargetType="{x:Type Thumb}">
      <Setter Property="OverridesDefaultStyle" Value="True"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Thumb}">
            <Border x:Name="th" Background="#8a8104" Margin="2,0" CornerRadius="0"/>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="th" Property="Background" Value="#fcee0a"/>
              </Trigger>
              <Trigger Property="IsDragging" Value="True">
                <Setter TargetName="th" Property="Background" Value="#fcee0a"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="VtScrollPage" TargetType="{x:Type RepeatButton}">
      <Setter Property="OverridesDefaultStyle" Value="True"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="IsTabStop" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type RepeatButton}">
            <Border Background="Transparent"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="{x:Type ScrollBar}">
      <Setter Property="Background" Value="#08090b"/>
      <Setter Property="Width" Value="10"/>
      <Setter Property="MinWidth" Value="10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ScrollBar}">
            <Grid Background="{TemplateBinding Background}">
              <Track Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Style="{StaticResource VtScrollPage}" Command="ScrollBar.PageUpCommand"/>
                </Track.DecreaseRepeatButton>
                <Track.Thumb>
                  <Thumb Style="{StaticResource VtScrollThumb}"/>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Style="{StaticResource VtScrollPage}" Command="ScrollBar.PageDownCommand"/>
                </Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="MinWidth" Value="0"/>
          <Setter Property="Height" Value="10"/>
          <Setter Property="MinHeight" Value="10"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="{x:Type ScrollBar}">
                <Grid Background="{TemplateBinding Background}">
                  <Track Name="PART_Track" IsDirectionReversed="False">
                    <Track.DecreaseRepeatButton>
                      <RepeatButton Style="{StaticResource VtScrollPage}" Command="ScrollBar.PageLeftCommand"/>
                    </Track.DecreaseRepeatButton>
                    <Track.Thumb>
                      <Thumb Style="{StaticResource VtScrollThumb}"/>
                    </Track.Thumb>
                    <Track.IncreaseRepeatButton>
                      <RepeatButton Style="{StaticResource VtScrollPage}" Command="ScrollBar.PageRightCommand"/>
                    </Track.IncreaseRepeatButton>
                  </Track>
                </Grid>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Grid Margin="20">
    <!-- Outer corner brackets -->
    <Border Style="{StaticResource CornerTL}"/>
    <Border Style="{StaticResource CornerTR}"/>
    <Border Style="{StaticResource CornerBL}"/>
    <Border Style="{StaticResource CornerBR}"/>

    <ScrollViewer x:Name="RootScroll" Margin="14"
                  VerticalScrollBarVisibility="Auto"
                  HorizontalScrollBarVisibility="Disabled"
                  Focusable="False">
    <Grid x:Name="RootGrid">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*" MinHeight="240"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- HEADER -->
      <StackPanel Grid.Row="0" HorizontalAlignment="Center" Margin="0,12,0,18">
        <TextBlock Text="V O R T E R M"
                   FontFamily="JetBrains Mono, Cascadia Mono, Consolas"
                   FontSize="42" FontWeight="Thin"
                   Foreground="{StaticResource Gold}"
                   HorizontalAlignment="Center">
          <TextBlock.Effect>
            <DropShadowEffect Color="#fcee0a" BlurRadius="22" ShadowDepth="0" Opacity="0.7"/>
          </TextBlock.Effect>
        </TextBlock>
        <TextBlock Text="VII.1"
                   FontFamily="JetBrains Mono, Cascadia Mono, Consolas"
                   FontSize="12" Foreground="{StaticResource Muted}"
                   HorizontalAlignment="Center" Margin="0,4,0,0"/>
      </StackPanel>

      <!-- PATH -->
      <Grid Grid.Row="1" Margin="8,4,8,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="I / STARTUP"
                   Style="{StaticResource RomanLabel}"
                   VerticalAlignment="Center" Margin="0,0,18,0"
                   ToolTip="Directorio inicial de las nuevas pestañas de terminal"/>
        <TextBox x:Name="PathBox" Grid.Column="1"
                 ToolTip="Directorio inicial de las nuevas pestañas de terminal"/>
        <Button x:Name="BrowseBtn" Grid.Column="2" Content="BROWSE"
                Style="{StaticResource GhostButton}" Margin="14,0,0,0"
                Padding="22,7" FontSize="13"/>
      </Grid>

      <!-- CONFIG: 3 columns -->
      <Grid Grid.Row="2" Margin="8,8,8,8">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Grid Grid.Column="0" Margin="0,0,18,0">
          <StackPanel>
            <TextBlock Text="II / SETUP" Style="{StaticResource RomanLabel}"/>
            <Border Style="{StaticResource SectionRule}"/>
            <CheckBox x:Name="cb_vscode"  Content="visual studio code"  IsChecked="False"/>
            <CheckBox x:Name="cb_neovim"  Content="neovim"              IsChecked="False"/>
            <CheckBox x:Name="cb_7zip"    Content="7-zip"               IsChecked="False"/>
            <CheckBox x:Name="cb_github"  Content="github desktop"      IsChecked="False"/>
            <CheckBox x:Name="cb_wsl"     Content="wsl (linux subsystem)" IsChecked="False"
                      ToolTip="Instala WSL2 + Ubuntu. Puede requerir reinicio."/>
          </StackPanel>
        </Grid>

        <Grid Grid.Column="1" Margin="0,0,18,0">
          <StackPanel>
            <TextBlock Text="III / RESET" Style="{StaticResource RomanLabel}"
                       Foreground="{StaticResource Danger}"/>
            <Border Style="{StaticResource SectionRule}" Background="{StaticResource Danger}"/>
            <CheckBox x:Name="cb_clean_profile" Content="powershell profiles" IsChecked="True"
                      ToolTip="Restaura backup Vorterm o mueve el perfil a .before-reset-*"/>
            <CheckBox x:Name="cb_clean_history" Content="psreadline history"  IsChecked="True"
                      ToolTip="Borra los ficheros *_history.txt de PSReadLine"/>
            <CheckBox x:Name="cb_clean_modules" Content="terminal modules"    IsChecked="True"
                      ToolTip="Desinstala Terminal-Icons, posh-git, oh-my-posh...&#10;Az/Graph/EXO y modulos de sistema NUNCA se tocan"/>
            <CheckBox x:Name="cb_clean_wt"      Content="windows terminal"    IsChecked="True"
                      ToolTip="Restaura settings.json desde backup Vorterm.&#10;Schemes y keybindings se conservan"/>
          </StackPanel>
        </Grid>

        <Grid Grid.Column="2">
          <StackPanel x:Name="PathsPanel">
            <TextBlock Text="IV / PATHS" Style="{StaticResource RomanLabel}"/>
            <Border Style="{StaticResource SectionRule}"/>
          </StackPanel>
        </Grid>
      </Grid>

      <!-- CONSOLE -->
      <Grid Grid.Row="3" Margin="8,8,8,8">
        <Border Style="{StaticResource CornerTL}"/>
        <Border Style="{StaticResource CornerTR}"/>
        <Border Style="{StaticResource CornerBL}"/>
        <Border Style="{StaticResource CornerBR}"/>
        <Grid Margin="14,12,14,12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0">
            <TextBlock Text="V / CONSOLE" Style="{StaticResource RomanLabel}"/>
            <Border Style="{StaticResource SectionRule}"/>
          </StackPanel>
          <RichTextBox x:Name="LogBox" Grid.Row="1" IsReadOnly="True" Background="Transparent"
                   BorderThickness="0"
                   FontFamily="JetBrains Mono, Cascadia Mono, Consolas"
                   FontSize="15" Foreground="#d9d9d9"
                   VerticalScrollBarVisibility="Auto"
                   HorizontalScrollBarVisibility="Auto"
                   IsUndoEnabled="False"
                   Padding="0,4,0,4"/>
        </Grid>
      </Grid>

      <!-- PROGRESS + PAUSE + STATUS -->
      <Grid Grid.Row="4" Margin="8,4,8,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <ProgressBar x:Name="Progress" Height="2" Minimum="0" Maximum="100"
                     VerticalAlignment="Center">
          <ProgressBar.Effect>
            <DropShadowEffect Color="#fcee0a" BlurRadius="8" ShadowDepth="0" Opacity="0.7"/>
          </ProgressBar.Effect>
        </ProgressBar>
        <Button x:Name="PauseBtn" Grid.Column="1" Content="PAUSE"
                Style="{StaticResource GhostButton}"
                Padding="18,6" FontSize="12"
                Margin="14,0,0,0"
                Visibility="Collapsed"
                ToolTip="Suspende/reanuda los instaladores en curso"/>
        <TextBlock x:Name="StatusText" Grid.Column="2" Text="IDLE"
                   FontFamily="JetBrains Mono, Cascadia Mono, Consolas"
                   Margin="16,0,4,0" VerticalAlignment="Center"
                   Foreground="{StaticResource Muted}" FontSize="13"/>
      </Grid>

      <!-- ACTIONS -->
      <StackPanel Grid.Row="5" Orientation="Horizontal"
                  HorizontalAlignment="Center" Margin="0,16,0,8">
        <Button x:Name="ExitBtn"    Content="EXIT"    Style="{StaticResource GhostButton}"   Margin="0,0,14,0"/>
        <Button x:Name="ResetBtn"   Content="RESET"   Style="{StaticResource WarningButton}" Margin="0,0,14,0"
                ToolTip="Deshace la configuracion Vorterm (con confirmacion)"/>
        <Button x:Name="InstallBtn" Content="INSTALL" Style="{StaticResource PrimaryButton}"
                ToolTip="Instala stack completo: PS7, WT, Git, Nerd Font, oh-my-posh + tema"/>
      </StackPanel>
    </Grid>
    </ScrollViewer>
  </Grid>
</Window>
'@

# ------ Load XAML -------------------------------------------
try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    # INSTALAR.bat corre con -WindowStyle Hidden: sin esto, un fallo de XAML
    # seria totalmente silencioso (doble click y "no pasa nada").
    [System.Windows.MessageBox]::Show(
        "Vorterm no pudo construir la interfaz:`n`n$($_.Exception.Message)",
        'Vorterm - error', 'OK', 'Error') | Out-Null
    exit 1
}

# Barra de titulo oscura + titulo dorado (Win10 19041+ / Win11; en builds
# viejos el atributo se ignora sin error)
$window.Add_SourceInitialized({
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        $on = 1
        [void][Vorterm.Dwm]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4)  # DWMWA_USE_IMMERSIVE_DARK_MODE
        [void][Vorterm.Dwm]::DwmSetWindowAttribute($hwnd, 19, [ref]$on, 4)  # id antiguo (builds < 19041)
        $caption = 0x00060505   # COLORREF BGR -> #050506 (fondo app), solo Win11
        [void][Vorterm.Dwm]::DwmSetWindowAttribute($hwnd, 35, [ref]$caption, 4) # DWMWA_CAPTION_COLOR
        $txt = 0x000AEEFC       # COLORREF BGR -> #fcee0a (dorado), solo Win11
        [void][Vorterm.Dwm]::DwmSetWindowAttribute($hwnd, 36, [ref]$txt, 4)     # DWMWA_TEXT_COLOR
    } catch {}
})

# Fit window to screen WorkArea, leaving small margin so taskbar / borders visible
$wa = [System.Windows.SystemParameters]::WorkArea
$marginX = 40
$marginY = 22
$window.Width  = [Math]::Min(1800, [Math]::Max(980, $wa.Width  - $marginX * 2))
$window.Height = [Math]::Min(1240, $wa.Height - $marginY * 2)
# Recenter dentro del area de trabajo (CenterScreen se calcula antes de este resize,
# asi que en pantallas chicas la ventana quedaba descentrada / con el borde inferior fuera)
$window.Left = $wa.Left + [Math]::Max(0, ($wa.Width  - $window.Width)  / 2)
$window.Top  = $wa.Top  + [Math]::Max(0, ($wa.Height - $window.Height) / 2)

$controls = @{}
foreach ($n in 'PathBox','BrowseBtn','LogBox','Progress','StatusText','ExitBtn','ResetBtn','InstallBtn','PauseBtn',
               'PathsPanel','RootScroll','RootGrid',
               'cb_vscode','cb_neovim','cb_7zip','cb_github','cb_wsl',
               'cb_clean_profile','cb_clean_wt','cb_clean_modules','cb_clean_history') {
    $controls[$n] = $window.FindName($n)
}

# Layout adaptativo: el grid llena el viewport del ScrollViewer cuando hay sitio
# (la fila estrella de la consola se estira); si la ventana es mas chica que el
# contenido minimo, aparece la scrollbar dorada en vez de cortar los botones.
$controls.RootScroll.Add_SizeChanged({
    $vh = $controls.RootScroll.ViewportHeight
    if ($vh -gt 0) { $controls.RootGrid.MinHeight = $vh }
})

# ------ Log document (RichTextBox con colores) ---------------
function Reset-LogDocument {
    $doc  = New-Object System.Windows.Documents.FlowDocument
    $doc.PageWidth = 2500   # sin word-wrap: scroll horizontal como una consola
    $para = New-Object System.Windows.Documents.Paragraph
    $para.Margin = [System.Windows.Thickness]::new(0)
    $doc.Blocks.Add($para)
    $controls.LogBox.Document = $doc
    $script:LogPara = $para
}
Reset-LogDocument

# ------ Populate Paths panel --------------------------------
function Open-PathTarget {
    param([string]$Target)
    if (-not $Target) { return }
    try {
        if (Test-Path $Target -PathType Leaf) {
            Start-Process explorer.exe -ArgumentList "/select,`"$Target`""
        } elseif (Test-Path $Target -PathType Container) {
            Start-Process explorer.exe -ArgumentList "`"$Target`""
        } else {
            $parent = Split-Path $Target -Parent
            if ($parent -and (Test-Path $parent)) {
                Start-Process explorer.exe -ArgumentList "`"$parent`""
            }
        }
    } catch {}
}

function Add-PathRow {
    param([string]$Label, [string]$Value)
    $exists = $false
    if ($Value) { $exists = Test-Path $Value -ErrorAction SilentlyContinue }
    $valueColor = if ($exists) { '#e8e8e8' } else { '#3a3b40' }

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $Label.ToUpper()
    $lbl.FontSize = 12
    $lbl.FontFamily = 'JetBrains Mono, Cascadia Mono, Consolas'
    $lbl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#8a8104')
    $lbl.Margin = '0,10,0,3'
    [void]$controls.PathsPanel.Children.Add($lbl)

    $val = New-Object System.Windows.Controls.TextBlock
    $val.Text = $Value
    $val.FontSize = 13
    $val.FontFamily = 'JetBrains Mono, Cascadia Mono, Consolas'
    $val.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($valueColor)
    $val.TextWrapping = 'Wrap'
    $val.Cursor = 'Hand'
    $val.Tag = $Value
    $val.ToolTip = "Click para abrir en Explorer"
    $val.Add_MouseLeftButtonUp({ Open-PathTarget $this.Tag })
    $val.Add_MouseEnter({ $this.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#fcee0a') })
    $origColor = $valueColor
    $val.Add_MouseLeave({ $this.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($origColor) }.GetNewClosure())
    [void]$controls.PathsPanel.Children.Add($val)
}

$pwshExePath = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $pwshExePath) {
    foreach ($p in "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                   "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
                   "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe") {
        if (Test-Path $p) { $pwshExePath = $p; break }
    }
}
if (-not $pwshExePath) { $pwshExePath = '(not installed)' }

Add-PathRow 'PS7 profile'        (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
Add-PathRow 'PS7 modules'        (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules')
Add-PathRow 'Windows Terminal'   "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Add-PathRow 'pwsh.exe'           $pwshExePath
Add-PathRow 'OMP themes folder'  (Join-Path $env:USERPROFILE '.poshthemes')
Add-PathRow 'OMP active theme'   (Join-Path $env:USERPROFILE ".poshthemes\$($script:ThemeFileName)")

$controls.PathBox.Text = Join-Path $env:USERPROFILE 'Documents'

$controls.BrowseBtn.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description         = 'Select startup directory'
    $dlg.SelectedPath        = $controls.PathBox.Text
    $dlg.ShowNewFolderButton = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $controls.PathBox.Text = $dlg.SelectedPath
    }
})

$controls.ExitBtn.Add_Click({ $window.Close() })

# ------ Sync state ------------------------------------------
$sync = [hashtable]::Synchronized(@{
    NoGui       = $false
    Window      = $window
    LogBox      = $controls.LogBox
    LogPara     = $script:LogPara
    Progress    = $controls.Progress
    StatusText  = $controls.StatusText
    InstallBtn  = $controls.InstallBtn
    ResetBtn    = $controls.ResetBtn
    PauseBtn    = $controls.PauseBtn
    ActiveProcs = [System.Collections.ArrayList]::new()
    Paused      = $false
})

# Pause / Resume click handler (suspends winget child procs)
$controls.PauseBtn.Add_Click({
    if ($sync.Paused) {
        foreach ($p in @($sync.ActiveProcs)) {
            if ($p -and -not $p.HasExited) {
                try { [Vorterm.ProcCtl]::NtResumeProcess($p.Handle) | Out-Null } catch {}
            }
        }
        $sync.Paused = $false
        $controls.PauseBtn.Content = 'Pause'
        $controls.StatusText.Text = 'Running'
    } else {
        foreach ($p in @($sync.ActiveProcs)) {
            if ($p -and -not $p.HasExited) {
                try { [Vorterm.ProcCtl]::NtSuspendProcess($p.Handle) | Out-Null } catch {}
            }
        }
        $sync.Paused = $true
        $controls.PauseBtn.Content = 'Resume'
        $controls.StatusText.Text = 'Paused'
    }
})

# ------ Install action --------------------------------------
$controls.InstallBtn.Add_Click({
    $opts = @{
        WorkDir      = $controls.PathBox.Text.Trim()
        Pwsh         = $true
        Git          = $true
        WT           = $true
        Font         = $true
        OMP          = $true
        PSRL         = $true
        Icons        = $true
        PoshGit      = $true
        WriteProfile = $true
        WTConfig     = $true
        Elevate      = $false
        VSCode       = $controls.cb_vscode.IsChecked
        Neovim       = $controls.cb_neovim.IsChecked
        SevenZip     = $controls.cb_7zip.IsChecked
        GitHubDesktop = $controls.cb_github.IsChecked
        WSL          = $controls.cb_wsl.IsChecked
        Policy       = $true
        Verify       = $true
        DryRun       = $false
        ThemeFile    = $script:ThemeFileName
        ThemeSrc     = $script:ThemeSrc
        ThemeJson    = $script:ThemeJson
    }

    if ([string]::IsNullOrWhiteSpace($opts.WorkDir)) {
        $opts.WorkDir = Join-Path $env:USERPROFILE 'Documents'
    }

    $controls.InstallBtn.IsEnabled = $false
    $controls.ResetBtn.IsEnabled   = $false
    Reset-LogDocument
    $sync.LogPara = $script:LogPara
    $controls.Progress.Value = 0
    $controls.StatusText.Text = 'Running'
    $controls.StatusText.Foreground = [Windows.Media.Brushes]::Gold

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $rs.SessionStateProxy.SetVariable('opts', $opts)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($InstallLogic.ToString())
    [void]$ps.BeginInvoke()
})

# ------ Reset action ----------------------------------------
$controls.ResetBtn.Add_Click({
    $msg = @"
Deep terminal reset. Se hara lo siguiente (segun checkbox):

 - PowerShell profiles: PS5.1 + PS7, todos los hosts (Console / ISE / VSCode / profile.ps1). Restaura el ultimo backup Vorterm, o mueve a .before-reset-* y borra. Tambien limpia la cache de init de oh-my-posh.
 - PSReadLine history: borra %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\*_history.txt
 - Terminal/prompt modules: desinstala Terminal-Icons, posh-git, oh-my-posh, PSReadLine, PSColor, Pansies, PSFzf, etc. Mas el paquete winget de oh-my-posh si existe.
 - Windows Terminal settings.json: restaura el ultimo backup Vorterm. Sin backup, quita solo claves Vorterm (commandline pwsh, Nerd font, elevate, startingDirectory). Schemes / keybindings intactos.

NUNCA se tocan: Az.*, Microsoft.Graph.*, MSOnline, ExchangeOnlineManagement, MicrosoftTeams, PnP.*, Pester, PSScriptAnalyzer, SqlServer, dbatools.
Apps que NO se desinstalan: PowerShell 7, Git, Windows Terminal, Nerd Font.

Continuar?
"@
    $confirm = [System.Windows.MessageBox]::Show(
        $msg,
        'Vorterm  -  Deep reset terminal',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $resetOpts = @{
        CleanProfile = $controls.cb_clean_profile.IsChecked
        CleanHistory = $controls.cb_clean_history.IsChecked
        CleanModules = $controls.cb_clean_modules.IsChecked
        CleanWT      = $controls.cb_clean_wt.IsChecked
        DryRun       = $false
    }

    $controls.InstallBtn.IsEnabled = $false
    $controls.ResetBtn.IsEnabled   = $false
    Reset-LogDocument
    $sync.LogPara = $script:LogPara
    $controls.Progress.Value = 0
    $controls.StatusText.Text = 'Resetting'
    $controls.StatusText.Foreground = [Windows.Media.Brushes]::Gold

    $rs2 = [runspacefactory]::CreateRunspace()
    $rs2.ApartmentState = 'STA'
    $rs2.ThreadOptions  = 'ReuseThread'
    $rs2.Open()
    $rs2.SessionStateProxy.SetVariable('sync', $sync)
    $rs2.SessionStateProxy.SetVariable('opts', $resetOpts)

    $ps2 = [powershell]::Create()
    $ps2.Runspace = $rs2
    [void]$ps2.AddScript($ResetLogic.ToString())
    [void]$ps2.BeginInvoke()
})

try {
    [void]$window.ShowDialog()
} catch {
    [System.Windows.MessageBox]::Show(
        "Vorterm crash:`n`n$($_.Exception.Message)",
        'Vorterm - error', 'OK', 'Error') | Out-Null
    exit 1
}
