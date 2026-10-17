<#
.SYNOPSIS
    WRITE. End-to-end test of the Vorterm installer. RUN ONLY IN A DISPOSABLE VIRTUAL MACHINE.

.DESCRIPTION
    Installs Vorterm for real (winget packages, profiles, Windows Terminal settings) in
    unattended mode and checks the acceptance criteria:
      A  install WITHOUT the LAB: no LAB anywhere, profile block + multi-pane, own profile
         content kept, Windows Terminal Mosaic profile, log file
      B  install WITH the LAB in a path with spaces and special characters
      C  second run: profile, Windows Terminal settings and LAB unchanged
      D  reset: Vorterm block and Mosaic removed, own profile content and LAB kept
    Results go to the console and, with -JsonOut, to a JSON file.

.PARAMETER IUnderstandThisInstallsSoftware
    Required switch. Proves you read the warning above.

.PARAMETER JsonOut
    Path of a JSON file with the results and the installer output.

.NOTES
    Context: admin (winget machine installs). Needs internet. Windows PowerShell 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][switch]$IUnderstandThisInstallsSoftware,
    [string]$JsonOut
)

# 'Continue': native exes (pwsh, winget) write to stderr and under 'Stop' Windows
# PowerShell 5.1 turns every such line into a terminating error.
$ErrorActionPreference = 'Continue'
$repo   = Split-Path -Parent $PSScriptRoot
$setup  = Join-Path $repo 'setup_terminal.ps1'
$ps51   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$docs   = [Environment]::GetFolderPath('MyDocuments')
$desk   = [Environment]::GetFolderPath('Desktop')
$labParent = Join-Path $desk ('Pruebas LAB (' + [char]0x00D1 + ') & co')
$results = New-Object System.Collections.ArrayList

function Add-Result([string]$Name, [bool]$Pass, [string]$Detail) {
    [void]$results.Add((New-Object psobject -Property ([ordered]@{ Test = $Name; Pass = $Pass; Detail = $Detail })))
    $tag = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Host ("[{0}] {1} - {2}" -f $tag, $Name, $Detail) -ForegroundColor $(if ($Pass) { 'Green' } else { 'Red' })
}

function Invoke-Setup([string[]]$ExtraArgs) {
    $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', $setup, '-NoGui', '-NoElevate') + $ExtraArgs
    # Start-Process joins ArgumentList with spaces and does not quote: quote by hand.
    $line = ($args2 | ForEach-Object { if ($_ -match '[\s&()]') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $stamp = Get-Date -Format HHmmssfff
    $log = Join-Path $env:TEMP "vorterm-e2e-$stamp.txt"
    $err = Join-Path $env:TEMP "vorterm-e2e-$stamp.err.txt"
    $p = Start-Process -FilePath $ps51 -ArgumentList $line -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $err
    $out = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath $err -Raw)
    return @{ Code = $p.ExitCode; Out = $out }
}

function Get-Ps7Profile {
    $pw = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pw) { $pw = Get-Item "$env:ProgramFiles\PowerShell\7\pwsh.exe" -ErrorAction SilentlyContinue }
    if ($pw) { return (& $pw.Source -NoProfile -Command '$PROFILE.CurrentUserCurrentHost').Trim() }
    return (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')
}

function Get-WtSettings {
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json" |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

function Get-Hash([string]$Path) { if ($Path -and (Test-Path -LiteralPath $Path)) { (Get-FileHash -LiteralPath $Path).Hash } }

# Windows Terminal writes settings.json the first time it starts
if (-not (Get-WtSettings) -and (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Start-Process wt.exe | Out-Null
    for ($i = 0; $i -lt 30 -and -not (Get-WtSettings); $i++) { Start-Sleep -Seconds 1 }
    Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Stop-Process -Force
}

# Own content in the PowerShell 7 profile: must survive install and reset
$p7 = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
New-Item -ItemType Directory -Path (Split-Path $p7) -Force | Out-Null
Set-Content -LiteralPath $p7 -Value "# my own line`r`nfunction Get-MyThing { 'mine' }" -Encoding ASCII

# ---- A: install without LAB --------------------------------------------------
$a = Invoke-Setup @('-WorkDir', $docs)
Add-Result 'A1 install exit code' ($a.Code -eq 0) "exit $($a.Code)"
$markers = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Filter '.vorterm-lab.json' -Recurse -Depth 4 -Force -ErrorAction SilentlyContinue)
Add-Result 'A2 no LAB created when not requested' ($markers.Count -eq 0) "$($markers.Count) LAB marker(s) found"
$p7 = Get-Ps7Profile
$prof = if (Test-Path -LiteralPath $p7) { [IO.File]::ReadAllText($p7) } else { '' }
Add-Result 'A3 profile has Vorterm block' (($prof -match '# >>> vorterm >>>') -and ($prof -match '# <<< vorterm <<<')) $p7
Add-Result 'A4 own profile content kept' ($prof -match 'Get-MyThing') 'Get-MyThing still there'
$pw = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pw) {
    $fn = & $pw.Source -NoLogo -NonInteractive -Command "if ((Get-Command m3 -EA 0) -and (Get-Command close -EA 0) -and (Get-Command Get-MyThing -EA 0)) { 'OK' }" 2>$null
    Add-Result 'A5 pwsh loads m3, close and own function' (($fn | Out-String) -match 'OK') ($fn | Out-String).Trim()
    $err = & $pw.Source -NoLogo -NonInteractive -Command "'__END__'" 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    Add-Result 'A6 profile loads without errors' (@($err).Count -eq 0) ((@($err) | Select-Object -First 2) -join ' | ')
}
$wt = Get-WtSettings
if ($wt) {
    $wj = Get-Content -LiteralPath $wt -Raw | ConvertFrom-Json
    $mos = @($wj.profiles.list | Where-Object { $_.guid -eq '{7628d9b6-6917-4040-b9a2-986f96f1361d}' })
    Add-Result 'A7 WT Mosaic profile (hidden, black, no image)' (($mos.Count -eq 1) -and $mos[0].hidden -and $mos[0].background -eq '#000000' -and -not $mos[0].backgroundImage) "count $($mos.Count)"
    $kb = @($wj.keybindings | Where-Object { $_.id -like 'User.Vorterm*' })
    Add-Result 'A8 WT shortcuts added' ($kb.Count -eq 3) "$($kb.Count) Vorterm keybindings"
} else {
    Add-Result 'A7 WT settings.json present' $false 'not found'
}
$logs = @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Vorterm\logs') -Filter 'install-*.log' -ErrorAction SilentlyContinue)
Add-Result 'A9 install log written' ($logs.Count -ge 1) "$($logs.Count) log file(s)"

# ---- B: install with LAB -------------------------------------------------------
New-Item -ItemType Directory -Path $labParent -Force | Out-Null
$b = Invoke-Setup @('-WorkDir', $docs, '-LabRoot', $labParent)
$labDir = Join-Path $labParent 'LAB'
Add-Result 'B1 install with LAB exit code' ($b.Code -eq 0) "exit $($b.Code)"
Add-Result 'B2 LAB created in chosen path' (Test-Path -LiteralPath (Join-Path $labDir '.vorterm-lab.json')) $labDir
$labFiles = @(Get-ChildItem -LiteralPath $labDir -Recurse -File -Force -ErrorAction SilentlyContinue).Count
Add-Result 'B3 LAB content' ($labFiles -gt 40) "$labFiles files"

# ---- C: second run is a no-op --------------------------------------------------
Set-Content -LiteralPath (Join-Path $labDir 'TODO.md') -Value 'my own todo' -Encoding ASCII
$h1 = @{ P = Get-Hash $p7; W = Get-Hash $wt }
$c = Invoke-Setup @('-WorkDir', $docs, '-LabRoot', $labParent)
$h2 = @{ P = Get-Hash $p7; W = Get-Hash $wt }
Add-Result 'C1 rerun exit code' ($c.Code -eq 0) "exit $($c.Code)"
Add-Result 'C2 profile unchanged on rerun' ($h1.P -eq $h2.P) 'hash compare'
Add-Result 'C3 WT settings unchanged on rerun' ($h1.W -eq $h2.W) 'hash compare'
Add-Result 'C4 LAB user edit kept' ((Get-Content -LiteralPath (Join-Path $labDir 'TODO.md') -Raw) -match 'my own todo') 'TODO.md'
Add-Result 'C5 rerun reports up to date' (($c.Out -match 'already up to date') -and ($c.Out -match 'LAB \(update\)')) 'log text'

# ---- D: reset ------------------------------------------------------------------
$d = Invoke-Setup @('-Reset')
$prof = if (Test-Path -LiteralPath $p7) { [IO.File]::ReadAllText($p7) } else { '' }
Add-Result 'D1 reset exit code' ($d.Code -eq 0) "exit $($d.Code)"
Add-Result 'D2 Vorterm block removed' ($prof -notmatch '# >>> vorterm >>>') $p7
Add-Result 'D3 own profile content kept after reset' ($prof -match 'Get-MyThing') 'Get-MyThing'
if ($wt) {
    $wj = Get-Content -LiteralPath $wt -Raw | ConvertFrom-Json
    $mos = @($wj.profiles.list | Where-Object { $_.guid -eq '{7628d9b6-6917-4040-b9a2-986f96f1361d}' })
    Add-Result 'D4 WT back to state before Vorterm' ($mos.Count -eq 0) "Mosaic count $($mos.Count)"
}
Add-Result 'D5 LAB untouched by reset' (Test-Path -LiteralPath (Join-Path $labDir '.vorterm-lab.json')) $labDir

if ($JsonOut) {
    New-Object psobject -Property ([ordered]@{ Computer = $env:COMPUTERNAME; Results = $results; OutA = $a.Out; OutC = $c.Out; OutD = $d.Out }) |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
}
$failed = @($results | Where-Object { -not $_.Pass })
Write-Host ("{0} checks, {1} failed" -f $results.Count, $failed.Count)
if ($failed.Count -gt 0) { exit 1 }
exit 0
