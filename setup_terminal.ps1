# =============================================================
#  TERMIX  v3.1 - professional terminal installer (WPF GUI)
#  Run via INSTALAR.bat (powershell.exe -STA -WindowStyle Hidden)
# =============================================================

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch {}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ------ XAML ------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TERMIX  -  Terminal Installer"
        Height="780" Width="1100"
        WindowStartupLocation="CenterScreen"
        Background="#0F1419"
        FontFamily="Segoe UI"
        FontSize="14"
        Foreground="#E5E9F0"
        ResizeMode="CanResize">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent"   Color="#4FC3F7"/>
    <SolidColorBrush x:Key="AccentHi" Color="#81D4FA"/>
    <SolidColorBrush x:Key="Panel"    Color="#161B22"/>
    <SolidColorBrush x:Key="PanelDeep" Color="#0B0E13"/>
    <SolidColorBrush x:Key="Border1"  Color="#2D3743"/>
    <SolidColorBrush x:Key="Muted"    Color="#8B95A8"/>
    <SolidColorBrush x:Key="Ok"       Color="#56D364"/>
    <SolidColorBrush x:Key="Warn"     Color="#DBAB0A"/>
    <SolidColorBrush x:Key="Err"      Color="#F85149"/>

    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="#E5E9F0"/>
      <Setter Property="FontSize" Value="14"/>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E5E9F0"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Margin" Value="0,6,24,6"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{StaticResource PanelDeep}"/>
      <Setter Property="Foreground" Value="#E5E9F0"/>
      <Setter Property="CaretBrush" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border1}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="FontFamily" Value="Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="14"/>
    </Style>

    <Style x:Key="GhostButton" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border1}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="14"/>
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
                <Setter TargetName="bd" Property="Background" Value="#1A2733"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="{StaticResource Accent}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#0E1620"/>
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
      <Setter Property="Foreground" Value="#F0883E"/>
      <Setter Property="BorderBrush" Value="#F0883E"/>
    </Style>

    <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource GhostButton}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="#0B0E13"/>
      <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="FontSize" Value="15"/>
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
                <Setter TargetName="bd" Property="Background" Value="{StaticResource AccentHi}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#3DA9D9"/>
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
      <Setter Property="Background" Value="{StaticResource PanelDeep}"/>
      <Setter Property="Foreground" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border1}"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>
  </Window.Resources>

  <Grid Margin="22">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- HEADER -->
    <Border Grid.Row="0" Background="{StaticResource Panel}"
            BorderBrush="{StaticResource Border1}" BorderThickness="1"
            Padding="22,18">
      <StackPanel>
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="T E R M I X" FontSize="28" FontWeight="Bold"
                     Foreground="{StaticResource Accent}"/>
          <TextBlock Text="  /  professional terminal installer"
                     FontSize="15" Foreground="{StaticResource Muted}"
                     VerticalAlignment="Bottom" Margin="10,0,0,4"/>
        </StackPanel>
        <TextBlock Text="v3.1   PowerShell 7 + Windows Terminal + Nerd Font + Modules"
                   Foreground="{StaticResource Muted}" FontSize="13" Margin="0,4,0,0"/>
      </StackPanel>
    </Border>

    <!-- PATH -->
    <Grid Grid.Row="1" Margin="0,18,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Text="Startup directory"
                 VerticalAlignment="Center"
                 Foreground="{StaticResource Accent}"
                 Margin="2,0,14,0"
                 FontWeight="SemiBold"
                 FontSize="14"/>
      <TextBox x:Name="PathBox" Grid.Column="1"/>
      <Button x:Name="BrowseBtn" Grid.Column="2"
              Content="Browse..." Style="{StaticResource GhostButton}"
              Margin="10,0,0,0"/>
    </Grid>

    <!-- COMPONENTS -->
    <Border Grid.Row="2" BorderBrush="{StaticResource Border1}" BorderThickness="1"
            Padding="18,14" Margin="0,8" Background="{StaticResource Panel}">
      <StackPanel>
        <TextBlock Text="Applications (winget)"
                   Foreground="{StaticResource Accent}"
                   FontWeight="Bold" Margin="0,0,0,6" FontSize="14"/>
        <WrapPanel>
          <CheckBox x:Name="cb_pwsh" Content="PowerShell 7"             IsChecked="True"/>
          <CheckBox x:Name="cb_git"  Content="Git"                      IsChecked="True"/>
          <CheckBox x:Name="cb_wt"   Content="Windows Terminal"         IsChecked="True"/>
          <CheckBox x:Name="cb_font" Content="JetBrainsMono Nerd Font"  IsChecked="True"/>
          <CheckBox x:Name="cb_omp"  Content="oh-my-posh (prompt theme)" IsChecked="True"/>
        </WrapPanel>

        <TextBlock Text="PowerShell modules"
                   Foreground="{StaticResource Accent}"
                   FontWeight="Bold" Margin="0,14,0,6" FontSize="14"/>
        <WrapPanel>
          <CheckBox x:Name="cb_psrl"    Content="PSReadLine 2.3.6"  IsChecked="True"/>
          <CheckBox x:Name="cb_icons"   Content="Terminal-Icons"    IsChecked="True"/>
          <CheckBox x:Name="cb_poshgit" Content="posh-git"          IsChecked="True"/>
        </WrapPanel>

        <TextBlock Text="Configuration"
                   Foreground="{StaticResource Accent}"
                   FontWeight="Bold" Margin="0,14,0,6" FontSize="14"/>
        <WrapPanel>
          <CheckBox x:Name="cb_profile"  Content="Write PowerShell profile"          IsChecked="True"/>
          <CheckBox x:Name="cb_wtcfg"    Content="Auto-configure Windows Terminal"   IsChecked="True"/>
          <CheckBox x:Name="cb_elevate"  Content="Run PowerShell 7 as Administrator" IsChecked="False"/>
          <CheckBox x:Name="cb_policy"   Content="Set ExecutionPolicy: RemoteSigned" IsChecked="True"/>
          <CheckBox x:Name="cb_verify"   Content="Verify install (Terminal-Icons / Font)" IsChecked="True"/>
        </WrapPanel>

        <TextBlock Text="Cleanup / reset"
                   Foreground="#F0883E"
                   FontWeight="Bold" Margin="0,14,0,6" FontSize="14"/>
        <WrapPanel>
          <CheckBox x:Name="cb_clean_profile" Content="Reset all PowerShell profiles (PS5.1 + PS7, all hosts)" IsChecked="True"/>
          <CheckBox x:Name="cb_clean_history" Content="Clear PSReadLine history"                                IsChecked="True"/>
          <CheckBox x:Name="cb_clean_modules" Content="Uninstall terminal/prompt modules (Icons, posh-git, oh-my-posh, ...)" IsChecked="True"/>
          <CheckBox x:Name="cb_clean_wt"      Content="Reset Windows Terminal settings (restore backup or strip TERMIX keys)" IsChecked="True"/>
        </WrapPanel>
      </StackPanel>
    </Border>

    <!-- LOG -->
    <Border Grid.Row="3" BorderBrush="{StaticResource Border1}" BorderThickness="1"
            Background="{StaticResource PanelDeep}" Margin="0,8">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Console output"
                   Foreground="{StaticResource Accent}"
                   FontWeight="Bold" Margin="14,10,0,4" FontSize="13"/>
        <TextBox x:Name="LogBox" Grid.Row="1" IsReadOnly="True" Background="Transparent"
                 BorderThickness="0" TextWrapping="NoWrap"
                 FontFamily="Cascadia Mono, Consolas"
                 FontSize="13"
                 Foreground="#A8C7E0"
                 VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto"
                 AcceptsReturn="True"/>
      </Grid>
    </Border>

    <!-- PROGRESS + STATUS -->
    <Grid Grid.Row="4" Margin="0,6,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <ProgressBar x:Name="Progress" Height="22" Minimum="0" Maximum="100"/>
      <TextBlock x:Name="StatusText" Grid.Column="1" Text="Idle"
                 Margin="14,0,4,0"
                 VerticalAlignment="Center"
                 Foreground="{StaticResource Muted}"
                 FontWeight="Bold" FontSize="14"/>
    </Grid>

    <!-- ACTIONS -->
    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="ExitBtn"    Content="Exit"            Style="{StaticResource GhostButton}"   Margin="0,0,10,0"/>
      <Button x:Name="ResetBtn"   Content="Reset terminal"  Style="{StaticResource WarningButton}" Margin="0,0,10,0"/>
      <Button x:Name="InstallBtn" Content="Execute install" Style="{StaticResource PrimaryButton}"/>
    </StackPanel>
  </Grid>
</Window>
'@

# ------ Load XAML -------------------------------------------
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
foreach ($n in 'PathBox','BrowseBtn','LogBox','Progress','StatusText','ExitBtn','ResetBtn','InstallBtn',
               'cb_pwsh','cb_git','cb_wt','cb_font','cb_omp','cb_psrl','cb_icons','cb_poshgit',
               'cb_profile','cb_wtcfg','cb_elevate','cb_policy','cb_verify',
               'cb_clean_profile','cb_clean_wt','cb_clean_modules','cb_clean_history') {
    $controls[$n] = $window.FindName($n)
}

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
    Window     = $window
    LogBox     = $controls.LogBox
    Progress   = $controls.Progress
    StatusText = $controls.StatusText
    InstallBtn = $controls.InstallBtn
    ResetBtn   = $controls.ResetBtn
})

# ------ Install action --------------------------------------
$controls.InstallBtn.Add_Click({
    $opts = @{
        WorkDir      = $controls.PathBox.Text.Trim()
        Pwsh         = $controls.cb_pwsh.IsChecked
        Git          = $controls.cb_git.IsChecked
        WT           = $controls.cb_wt.IsChecked
        Font         = $controls.cb_font.IsChecked
        OMP          = $controls.cb_omp.IsChecked
        PSRL         = $controls.cb_psrl.IsChecked
        Icons        = $controls.cb_icons.IsChecked
        PoshGit      = $controls.cb_poshgit.IsChecked
        WriteProfile = $controls.cb_profile.IsChecked
        WTConfig     = $controls.cb_wtcfg.IsChecked
        Elevate      = $controls.cb_elevate.IsChecked
        Policy       = $controls.cb_policy.IsChecked
        Verify       = $controls.cb_verify.IsChecked
    }

    if ([string]::IsNullOrWhiteSpace($opts.WorkDir)) {
        $opts.WorkDir = Join-Path $env:USERPROFILE 'Documents'
    }

    $controls.InstallBtn.IsEnabled = $false
    $controls.ResetBtn.IsEnabled   = $false
    $controls.LogBox.Clear()
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

    [void]$ps.AddScript({

        function Write-Log {
            param([string]$Msg)
            $sync.Window.Dispatcher.Invoke([action]{
                $sync.LogBox.AppendText("$Msg`r`n")
                $sync.LogBox.ScrollToEnd()
            })
        }
        function Set-Status {
            param([string]$Text, [int]$Pct = -1)
            $sync.Window.Dispatcher.Invoke([action]{
                $sync.StatusText.Text = $Text
                if ($Pct -ge 0) { $sync.Progress.Value = $Pct }
            })
        }

        $started = Get-Date
        $script:failures = @()

        Write-Log "============================================================"
        Write-Log "  TERMIX install started  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "  Startup dir: $($opts.WorkDir)"
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
            try {
                New-Item -ItemType Directory -Path $opts.WorkDir -Force | Out-Null
                Write-Log "  [OK] created: $($opts.WorkDir)"
            } catch {
                Write-Log "  [!!] could not create, fallback to Documents"
                $opts.WorkDir = Join-Path $env:USERPROFILE 'Documents'
            }
        } else { Write-Log "  [OK] dir exists" }

        # ---- Execution policy ----------------------------
        if ($opts.Policy) {
            Set-Status 'Policy' 8
            try {
                $eff = Get-ExecutionPolicy
                if ($eff -in @('Restricted','AllSigned','Undefined')) {
                    try {
                        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
                        Write-Log "  [OK] policy CurrentUser -> RemoteSigned"
                    } catch {
                        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
                        Write-Log "  [!!] GPO blocked. Process scope -> Bypass"
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
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
                Write-Log "  [OK] NuGet provider installed"
            } else { Write-Log "  [OK] NuGet provider" }

            if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                Write-Log "  [OK] PSGallery -> Trusted"
            } else { Write-Log "  [OK] PSGallery trusted" }
        } catch { Write-Log "  [!!] gallery: $($_.Exception.Message)" }

        # ---- Winget packages (PARALLEL) ------------------
        Set-Status 'Packages' 18

        $pkgs = @()
        if ($opts.Pwsh -and -not $pwshExe) {
            $pkgs += @{ Id='Microsoft.PowerShell';        Name='PowerShell 7' }
        } elseif ($opts.Pwsh) {
            Write-Log "  [OK] PowerShell 7 already installed"
        }
        if ($opts.Git)  { $pkgs += @{ Id='Git.Git';                       Name='Git' } }
        if ($opts.WT)   { $pkgs += @{ Id='Microsoft.WindowsTerminal';     Name='Windows Terminal' } }
        if ($opts.Font) { $pkgs += @{ Id='DEVCOM.JetBrainsMonoNerdFont';  Name='JetBrainsMono Nerd Font' } }
        if ($opts.OMP)  { $pkgs += @{ Id='JanDeDobbeleer.OhMyPosh';       Name='oh-my-posh' } }

        if ($hasWinget -and $pkgs.Count -gt 0) {
            Write-Log "  [..] launching $($pkgs.Count) winget installs in parallel..."
            $procs = @{}
            foreach ($p in $pkgs) {
                Write-Log "       -> $($p.Name)"
                $args = @(
                    'install','--id',$p.Id,'-e','--silent',
                    '--accept-package-agreements','--accept-source-agreements',
                    '--disable-interactivity'
                )
                $proc = Start-Process winget -ArgumentList $args -WindowStyle Hidden -PassThru
                $procs[$p.Name] = $proc
            }

            $total = $procs.Count
            $done  = 0
            while ($done -lt $total) {
                Start-Sleep -Milliseconds 500
                $done = ($procs.Values | Where-Object { $_.HasExited }).Count
                $pct  = 18 + [int](40 * $done / $total)
                Set-Status "Packages ($done/$total)" $pct
            }

            foreach ($name in $procs.Keys) {
                $code = $procs[$name].ExitCode
                # winget exit codes: 0 ok; -1978335189 = no upgrade available; -1978335212 = no applicable upgrade
                $okCodes = @(0, -1978335189, -1978335212)
                if ($okCodes -contains $code) {
                    Write-Log ("  [OK] {0}" -f $name)
                } else {
                    Write-Log ("  [!!] {0} (exit 0x{1:X8})" -f $name, $code)
                    $script:failures += $name
                }
            }
        } elseif (-not $hasWinget -and $pkgs.Count) {
            Write-Log "  [!!] winget missing, skipping all packages"
        }

        # Refresh PATH + re-locate pwsh
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        if (-not $pwshExe) { $pwshExe = Find-Pwsh }

        # ---- PS modules ----------------------------------
        Set-Status 'Modules' 60

        # Save-Module a paths PS7 + PS5.1 explicitos.
        # Razon: si script corre en PS5.1 (powershell.exe), Install-Module -Scope CurrentUser
        # cae en Documents\WindowsPowerShell\Modules (PS5.1 path) y PS7 NO lo ve.
        # Save-Module evita esa ambiguedad.
        function Install-PSMod {
            param([string]$Name, [string]$Version)
            $ps7Mod = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules'
            $ps5Mod = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules'
            foreach ($d in @($ps7Mod, $ps5Mod)) {
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            }

            try {
                $cur = Get-Module -ListAvailable -Name $Name |
                       Sort-Object Version -Descending | Select-Object -First 1
                $needInstall = $true
                if ($Version) {
                    if ($cur -and $cur.Version -ge [version]$Version) { $needInstall = $false }
                } elseif ($cur) {
                    $needInstall = $false
                }

                # Comprobar presencia fisica en path PS7 (lo critico)
                $ps7Has = Test-Path (Join-Path $ps7Mod $Name)

                if (-not $needInstall -and $ps7Has) {
                    Write-Log "  [OK] $Name $($cur.Version) ya presente (PS7 path)"
                    return
                }

                Write-Log ("  [..] {0} {1} -> Save-Module a {2}" -f $Name,$Version,$ps7Mod)
                $saveArgs = @{
                    Name        = $Name
                    Path        = $ps7Mod
                    Force       = $true
                    ErrorAction = 'Stop'
                }
                if ($Version) { $saveArgs.RequiredVersion = $Version }
                Save-Module @saveArgs

                # Mirror a PS5.1 path para que ambos hosts vean el modulo
                if (-not (Test-Path (Join-Path $ps5Mod $Name))) {
                    try {
                        Copy-Item (Join-Path $ps7Mod $Name) -Destination $ps5Mod -Recurse -Force -ErrorAction Stop
                    } catch {
                        Write-Log "  [..] mirror $Name a PS5.1 fallo (no critico): $($_.Exception.Message)"
                    }
                }
                Write-Log "  [OK] $Name instalado"
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
            Set-Status "Modules ($modIdx/$($modList.Count))" (60 + [int](15 * $modIdx / [Math]::Max(1,$modList.Count)))
            Install-PSMod -Name $m.N -Version $m.V
        }

        # ---- Detect actual Nerd Font name ----------------
        function Get-InstalledNerdFont {
            $fonts = @()
            foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                              'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
                if (Test-Path $hive) {
                    $fonts += (Get-ItemProperty $hive).PSObject.Properties |
                              Where-Object { $_.Name -notlike 'PS*' } |
                              Select-Object -ExpandProperty Name
                }
            }
            # Familia full ("Nerd Font") > NFM (Mono, mejor para terminal) > NF
            $patterns = @(
                @{ Rx = '^JetBrainsMono Nerd Font Regular' ; Family = 'JetBrainsMono Nerd Font' },
                @{ Rx = '^JetBrainsMono NFM Regular'        ; Family = 'JetBrainsMono NFM'        },
                @{ Rx = '^JetBrainsMono NF Regular'         ; Family = 'JetBrainsMono NF'         }
            )
            foreach ($p in $patterns) {
                if ($fonts -match $p.Rx) { return $p.Family }
            }
            # Fallback generico para cualquier Nerd Font instalada
            $any = $fonts | Where-Object { $_ -match '(?i)(Nerd|\bNF[MP]?\b)' -and $_ -notmatch 'Bold|Italic|Light|Thin|Medium|Extra|Semi' } |
                   Select-Object -First 1
            if ($any) { return ($any -replace '\s+Regular\s*\(TrueType\)\s*$','' -replace '\s*\(TrueType\)\s*$','').Trim() }
            return 'JetBrainsMono NF'
        }
        $nerdFontFace = Get-InstalledNerdFont
        Write-Log "  [OK] detected font face: '$nerdFontFace'"

        # ---- PowerShell profile --------------------------
        if ($opts.WriteProfile) {
            Set-Status 'Profile' 80

            $ps7Dir  = Join-Path $env:USERPROFILE 'Documents\PowerShell'
            $ps7Path = Join-Path $ps7Dir 'Microsoft.PowerShell_profile.ps1'
            $ps5Dir  = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
            $ps5Path = Join-Path $ps5Dir 'Microsoft.PowerShell_profile.ps1'

            foreach ($d in @($ps7Dir,$ps5Dir)) {
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
            }

            $escapedPath = $opts.WorkDir -replace "'", "''"

            $profileContent = @"
# === Generated by TERMIX v3.4 - visual / terminal config ======

# --- Extra PATH (developer tools when present) ----------------
`$extraPaths = @(
    'C:\Program Files\Git\bin',
    'C:\Program Files\Git\cmd',
    'C:\Program Files\nodejs',
    'C:\Program Files\Vim\vim90',
    'C:\Program Files (x86)\GnuWin32\bin'
)
foreach (`$p in `$extraPaths) {
    if ((Test-Path `$p) -and (`$env:Path -notlike "*`$p*")) { `$env:Path += ";`$p" }
}

# --- oh-my-posh (prompt + glyphs) -----------------------------
`$script:_ompActive = `$false
if (Get-Command oh-my-posh.exe -ErrorAction SilentlyContinue) {
    `$theme = `$null
    # Path preferido: ~\.poshthemes (downloaded by setup)
    `$candidate = Join-Path `$env:USERPROFILE '.poshthemes\darkblood.omp.json'
    if (Test-Path `$candidate) { `$theme = `$candidate }
    if (-not `$theme -and `$env:POSH_THEMES_PATH) {
        `$candidate = Join-Path `$env:POSH_THEMES_PATH 'darkblood.omp.json'
        if (Test-Path `$candidate) { `$theme = `$candidate }
    }
    if (-not `$theme) {
        `$candidate = Join-Path `$env:LOCALAPPDATA 'Programs\oh-my-posh\themes\darkblood.omp.json'
        if (Test-Path `$candidate) { `$theme = `$candidate }
    }
    if (`$theme) {
        oh-my-posh init pwsh --config `$theme | Invoke-Expression
        `$script:_ompActive = `$true
    } else {
        oh-my-posh init pwsh | Invoke-Expression
        `$script:_ompActive = `$true
    }
}

# --- Modulos: import directo (sin Get-Module -ListAvailable, ~10x mas rapido) -
Import-Module posh-git       -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module PSReadLine     -ErrorAction SilentlyContinue

# --- PSReadLine config (opciones no soportadas en 2.0 caen en silencio) -------
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally -ErrorAction SilentlyContinue
    Set-PSReadLineOption -MaximumHistoryCount 20000          -ErrorAction SilentlyContinue
    Set-PSReadLineOption -BellStyle None                     -ErrorAction SilentlyContinue
    Set-PSReadLineOption -EditMode Windows                   -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionSource History           -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle ListView       -ErrorAction SilentlyContinue

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

# --- Aliases --------------------------------------------------
Set-Alias ll    Get-ChildItem
Set-Alias g     git
Set-Alias grep  Select-String
Set-Alias which Get-Command
Set-Alias touch New-Item

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
if (-not `$global:__TermixStarted) {
    Set-Location '$escapedPath'
    `$global:__TermixStarted = `$true
    Clear-Host
}
"@

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

        # ---- Windows Terminal config ---------------------
        if ($opts.WTConfig) {
            Set-Status 'Windows Terminal config' 90

            $wtCandidates = @(
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
                "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
            ) | Where-Object { Test-Path $_ }

            if (-not $wtCandidates) {
                Write-Log "  [!!] Windows Terminal settings.json not found (open WT once to generate it)"
            } else {
                $ps7Guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'

                # PS5.1 ConvertFrom-Json does not understand // and /* */ comments.
                # WT settings.json is JSONC; strip comments while preserving strings.
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
                            } else {
                                [void]$sb.Append($c); $i++
                            }
                        }
                    }
                    $sb.ToString()
                }

                foreach ($wtJson in $wtCandidates) {
                    try {
                        $bk = "$wtJson.bak-$(Get-Date -Format yyyyMMddHHmmss)"
                        Copy-Item $wtJson $bk -Force
                        Write-Log "  [..] backup WT: $bk"

                        $raw   = Get-Content $wtJson -Raw -Encoding UTF8
                        $clean = Remove-JsonComments $raw
                        $json  = $clean | ConvertFrom-Json

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
                                $isPwsh = ($prof.guid -eq $ps7Guid) -or
                                          ($prof.commandline -match 'pwsh') -or
                                          ($prof.name -match 'PowerShell')
                                if ($isPwsh) {
                                    Set-Prop $prof 'commandline' 'pwsh.exe -NoLogo -NoProfileLoadTime'
                                    Set-Prop $prof 'startingDirectory' $opts.WorkDir
                                    if ($opts.Elevate) {
                                        Set-Prop $prof 'elevate' $true
                                    }
                                    if (-not $prof.font) {
                                        Set-Prop $prof 'font' ([pscustomobject]@{ face = $nerdFontFace; size = 11 })
                                    } else {
                                        Set-Prop $prof.font 'face' $nerdFontFace
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
                                font              = [pscustomobject]@{ face = $nerdFontFace; size = 11 }
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
            Set-Status 'Verify' 96
            if ($pwshExe -and $opts.Icons) {
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

                    # Asegurar darkblood en ~\.poshthemes (path estable, no depende de MSIX)
                    $userThemes = Join-Path $env:USERPROFILE '.poshthemes'
                    if (-not (Test-Path $userThemes)) {
                        New-Item -ItemType Directory -Path $userThemes -Force | Out-Null
                    }
                    $userTheme = Join-Path $userThemes 'darkblood.omp.json'
                    if (-not (Test-Path $userTheme)) {
                        try {
                            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/darkblood.omp.json' `
                                -OutFile $userTheme -UseBasicParsing -ErrorAction Stop
                            Write-Log "  [OK] darkblood downloaded to $userTheme"
                        } catch {
                            Write-Log "  [!!] download darkblood: $($_.Exception.Message)"
                            $script:failures += 'omp-theme-download'
                        }
                    } else {
                        Write-Log "  [OK] darkblood already at $userTheme"
                    }

                    # Setear POSH_THEMES_PATH user env si esta vacio
                    if (-not [Environment]::GetEnvironmentVariable('POSH_THEMES_PATH','User')) {
                        [Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $userThemes, 'User')
                        Write-Log "  [OK] POSH_THEMES_PATH (User) -> $userThemes"
                    }
                } else {
                    Write-Log "  [!!] oh-my-posh.exe not found"
                    $script:failures += 'omp-bin'
                }
            }

            $hasFont = $false
            foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                              'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
                if (Test-Path $hive) {
                    $names = (Get-ItemProperty $hive).PSObject.Properties.Name
                    if ($names -match '(?i)Nerd') { $hasFont = $true; break }
                }
            }
            if ($hasFont) {
                Write-Log "  [OK] Nerd Font detected in registry"
            } else {
                Write-Log "  [!!] No Nerd Font detected. ls icons will not render"
                $script:failures += 'nerd-font'
            }
        }

        # ---- Done ----------------------------------------
        Set-Status 'Done' 100
        $elapsed = (Get-Date) - $started
        Write-Log ""
        Write-Log "============================================================"
        if ($script:failures.Count -gt 0) {
            Write-Log "  Finished with warnings: $($script:failures -join ', ')"
        } else {
            Write-Log "  All green. System ready."
        }
        Write-Log ("  Elapsed: {0:N1}s" -f $elapsed.TotalSeconds)
        Write-Log "============================================================"
        Write-Log ""
        Write-Log "Next: CLOSE Windows Terminal completely and reopen it. New process picks up the Nerd Font and POSH_THEMES_PATH."
        Write-Log "First tab loads PowerShell 7 with oh-my-posh prompt + Terminal-Icons + posh-git."
        if ($opts.Elevate) {
            Write-Log "Note: PowerShell 7 profile is set to elevate. Each new tab prompts UAC."
        }
        Write-Log "If glyphs still render as boxes: Settings -> Profiles -> PowerShell -> Appearance -> Font, pick the Nerd Font manually."
        Write-Log "Helpers: html <file|url>, open <path>, serve [-Port], sudo <cmd>, profile, SysInfo, Update-Modules."

        $sync.Window.Dispatcher.Invoke([action]{
            $sync.InstallBtn.IsEnabled = $true
            $sync.ResetBtn.IsEnabled   = $true
            if ($script:failures.Count) {
                $sync.StatusText.Text = 'Warnings'
                $sync.StatusText.Foreground = [Windows.Media.Brushes]::Goldenrod
            } else {
                $sync.StatusText.Text = 'Ready'
                $sync.StatusText.Foreground = [Windows.Media.Brushes]::LightGreen
            }
        })
    })

    [void]$ps.BeginInvoke()
})

# ------ Reset action ----------------------------------------
$controls.ResetBtn.Add_Click({
    $msg = @"
Deep terminal reset. The following will be performed (per checkbox):

 - PowerShell profiles: scan PS5.1 + PS7, all hosts (Console / ISE / VSCode / profile.ps1). Restore from latest TERMIX backup, or move to .before-reset-* and delete.
 - PSReadLine history: wipe %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\*_history.txt
 - Terminal/prompt modules: uninstall Terminal-Icons, posh-git, oh-my-posh, PSReadLine, PSColor, Pansies, PSFzf, PSEverything, BurntToast, etc. Plus oh-my-posh winget package if present.
 - Windows Terminal settings.json: restore latest TERMIX backup. If no backup, strip only TERMIX-set keys (commandline pwsh, Nerd font, elevate, startingDirectory). Color schemes / keybindings / themes preserved.

Skipped (never touched): Az.*, Microsoft.Graph.*, MSOnline, ExchangeOnlineManagement, MicrosoftTeams, PnP.*, Pester, PSScriptAnalyzer, SqlServer, dbatools.
Apps NOT uninstalled: PowerShell 7, Git, Windows Terminal, Nerd Font.

Continue?
"@
    $confirm = [System.Windows.MessageBox]::Show(
        $msg,
        'TERMIX  -  Deep reset terminal',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $resetOpts = @{
        CleanProfile = $controls.cb_clean_profile.IsChecked
        CleanHistory = $controls.cb_clean_history.IsChecked
        CleanModules = $controls.cb_clean_modules.IsChecked
        CleanWT      = $controls.cb_clean_wt.IsChecked
    }

    $controls.InstallBtn.IsEnabled = $false
    $controls.ResetBtn.IsEnabled   = $false
    $controls.LogBox.Clear()
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

    [void]$ps2.AddScript({

        function Write-Log {
            param([string]$Msg)
            $sync.Window.Dispatcher.Invoke([action]{
                $sync.LogBox.AppendText("$Msg`r`n")
                $sync.LogBox.ScrollToEnd()
            })
        }
        function Set-Status {
            param([string]$Text, [int]$Pct = -1)
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

        Write-Log "============================================================"
        Write-Log "  TERMIX deep reset  $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
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
                            Copy-Item $bks[0].FullName $p -Force
                            Write-Log "  [OK] restored $p"
                            Write-Log "       from: $($bks[0].Name)"
                        } elseif (Test-Path $p) {
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
            try {
                Clear-History -ErrorAction SilentlyContinue
                Write-Log "  [OK] in-session history cleared"
            } catch {}
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
                        Write-Log "  [..] uninstalling oh-my-posh (winget package)..."
                        winget uninstall --id JanDeDobbeleer.OhMyPosh -e --silent --disable-interactivity 2>&1 | Out-Null
                        Write-Log "  [OK] oh-my-posh winget package removed"
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
                            Copy-Item $bks[0].FullName $wt -Force
                            Write-Log "  [OK] restored $wt"
                            Write-Log "       from: $($bks[0].Name)"
                            continue
                        }

                        # No backup: strip TERMIX markers in-place
                        Write-Log "  [..] no backup for $wt, stripping TERMIX keys..."
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
                            Write-Log "  [..] no TERMIX markers found, file unchanged"
                        }
                    } catch {
                        Write-Log "  [!!] $wt : $($_.Exception.Message)"
                        $failures += 'wt'
                    }
                }
            }
        }

        Set-Status 'Done' 100
        $elapsed = (Get-Date) - $started
        Write-Log ""
        Write-Log "============================================================"
        if ($failures.Count) {
            Write-Log "  Reset finished with warnings: $($failures -join ', ')"
        } else {
            Write-Log "  Deep reset complete. Terminal back to clean state."
        }
        Write-Log ("  Elapsed: {0:N1}s" -f $elapsed.TotalSeconds)
        Write-Log "============================================================"
        Write-Log ""
        Write-Log "Untouched: PowerShell 7, Git, Windows Terminal, Nerd Font, Az/Graph/EXO modules."
        Write-Log "Open a new terminal window to see the clean state (current session keeps loaded modules in memory)."

        $sync.Window.Dispatcher.Invoke([action]{
            $sync.InstallBtn.IsEnabled = $true
            $sync.ResetBtn.IsEnabled   = $true
            if ($failures.Count) {
                $sync.StatusText.Text = 'Warnings'
                $sync.StatusText.Foreground = [Windows.Media.Brushes]::Goldenrod
            } else {
                $sync.StatusText.Text = 'Reset done'
                $sync.StatusText.Foreground = [Windows.Media.Brushes]::LightGreen
            }
        })
    })

    [void]$ps2.BeginInvoke()
})

[void]$window.ShowDialog()
