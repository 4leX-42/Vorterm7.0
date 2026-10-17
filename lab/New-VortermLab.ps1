<#
.SYNOPSIS
    Creates or updates a Vorterm "LAB" (laboratorio) working folder from the bundled template.

.DESCRIPTION
    Local file operation only. It does not use the network, does not sign in anywhere,
    does not need administrator rights and never touches Azure, Microsoft 365 or any
    other service.

    Safety rules:
      - The LAB is always created as <Root>\<Name> (default name: LAB).
      - A file that already exists is never overwritten unless Vorterm wrote it and the
        user has not changed it since (tracked by hash in .vorterm-lab.json).
      - Nothing is ever deleted.
      - An existing folder that was not created by Vorterm is reported as a conflict.
        -Adopt adds only the missing files to it.

    Exit codes (when run without -PassThru):
      0 ok | 1 invalid path or no write permission | 2 conflict | 3 finished with errors

.PARAMETER Root
    Existing parent folder, for example "$env:USERPROFILE\Desktop".

.PARAMETER Name
    Name of the LAB folder created inside Root. Default: LAB.

.PARAMETER Adopt
    Use an existing folder that was not created by Vorterm: add missing files only.

.PARAMETER DryRun
    Report what would change without writing anything.

.PARAMETER ValidateOnly
    Check the target (path, permissions, existing LAB) and stop.

.PARAMETER PassThru
    Return the result object instead of printing a summary and setting the exit code.

.EXAMPLE
    .\New-VortermLab.ps1 -Root "$env:USERPROFILE\Desktop"

.EXAMPLE
    .\New-VortermLab.ps1 -Root 'D:\Work' -DryRun

.NOTES
    Context: user. Compatible with Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$Name = 'LAB',
    [switch]$Adopt,
    [switch]$DryRun,
    [switch]$ValidateOnly,
    [switch]$PassThru,
    [string]$TemplatePath,
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $TemplatePath) { $TemplatePath = Join-Path $here 'template' }
if (-not $ManifestPath) { $ManifestPath = Join-Path $here 'lab-manifest.json' }

$MarkerName = '.vorterm-lab.json'
$ToolId     = 'vorterm-lab'

$result = New-Object psobject -Property @{
    Status      = 'ok'
    ExitCode    = 0
    Mode        = $null
    LabPath     = $null
    Version     = $null
    DryRun      = [bool]$DryRun
    Created     = @()
    Updated     = @()
    Unchanged   = @()
    Kept        = @()
    Directories = @()
    Errors      = @()
    Messages    = @()
}

function Stop-Lab {
    param([string]$Status, [int]$Code, [string]$Message)
    $result.Status   = $Status
    $result.ExitCode = $Code
    $result.Errors  += $Message
}

function Get-RelativeDestination {
    # Template names use a "dot-" prefix for dotfiles so the template itself is not
    # treated as a git or Claude Code folder inside the Vorterm repository.
    param([string]$Relative)
    $parts = $Relative -split '[\\/]'
    $mapped = foreach ($p in $parts) { if ($p -like 'dot-*') { '.' + $p.Substring(4) } else { $p } }
    return ($mapped -join '\')
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-WriteAccess {
    param([string]$Dir)
    $probe = Join-Path $Dir (".vorterm-write-test-" + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'probe')
        [IO.File]::Delete($probe)
        return $null
    } catch {
        return $_.Exception.Message
    }
}

function Write-Summary {
    $line = '=' * 64
    Write-Host $line
    $label = if ($result.DryRun) { 'DRY RUN - nothing was written' } else { "Mode: $($result.Mode)" }
    Write-Host "  Vorterm LAB  $label"
    if ($result.LabPath) { Write-Host "  Path: $($result.LabPath)" }
    if ($result.Version) { Write-Host "  Template version: $($result.Version)" }
    Write-Host $line
    Write-Host ("  created {0} | updated {1} | unchanged {2} | kept (yours) {3} | folders {4}" -f `
        $result.Created.Count, $result.Updated.Count, $result.Unchanged.Count, $result.Kept.Count, $result.Directories.Count)
    foreach ($k in $result.Kept)     { Write-Host "  [kept] $k (modified by you, not overwritten)" -ForegroundColor DarkGray }
    foreach ($m in $result.Messages) { Write-Host "  [..] $m" -ForegroundColor DarkGray }
    foreach ($e in $result.Errors)   { Write-Host "  [!!] $e" -ForegroundColor Red }
    $color = if ($result.ExitCode -eq 0) { 'Green' } else { 'Yellow' }
    Write-Host "  Status: $($result.Status)" -ForegroundColor $color
}

function Complete-Lab {
    if ($PassThru) { return $result }
    Write-Summary
    exit $result.ExitCode
}

# ---- Template ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $TemplatePath -PathType Container) -or
    -not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Stop-Lab 'error' 1 "LAB template not found next to the script ($TemplatePath)."
    return (Complete-Lab)
}
try {
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
} catch {
    Stop-Lab 'error' 1 "Invalid lab-manifest.json: $($_.Exception.Message)"
    return (Complete-Lab)
}
$result.Version = [string]$manifest.version

# ---- Validate target --------------------------------------------------------
$rootIn = if ($Root) { $Root.Trim().Trim('"').Trim() } else { '' }
$err = $null
if (-not $rootIn) {
    $err = 'The destination folder is empty.'
} elseif ($rootIn.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) {
    $err = "The destination contains characters Windows does not allow: $rootIn"
} elseif (-not [IO.Path]::IsPathRooted($rootIn) -or $rootIn -match '^[A-Za-z]:(?![\\/])') {
    $err = "Use a full path such as C:\Users\you\Desktop (got: $rootIn)."
} elseif (-not $Name -or $Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $Name -in @('.', '..')) {
    $err = "Invalid LAB folder name: $Name"
}
if ($err) { Stop-Lab 'error' 1 $err; return (Complete-Lab) }

try { $rootFull = [IO.Path]::GetFullPath($rootIn).TrimEnd('\') } catch {
    Stop-Lab 'error' 1 "Invalid destination path: $($_.Exception.Message)"; return (Complete-Lab)
}
if ($rootFull -match '^[A-Za-z]:$') { $rootFull += '\' }

if (Test-Path -LiteralPath $rootFull -PathType Leaf) {
    Stop-Lab 'error' 1 "The destination is a file, not a folder: $rootFull"; return (Complete-Lab)
}
if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
    Stop-Lab 'error' 1 "The destination folder does not exist: $rootFull"; return (Complete-Lab)
}

$protected = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432) |
    Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
foreach ($p in $protected) {
    if ($rootFull -ieq $p -or $rootFull.StartsWith($p + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Lab 'error' 1 "System folders are not allowed as LAB location: $rootFull"; return (Complete-Lab)
    }
}

$labPath = Join-Path $rootFull $Name
$result.LabPath = $labPath

$templateFiles = @(Get-ChildItem -LiteralPath $TemplatePath -Recurse -File -Force)
$plan = foreach ($f in $templateFiles) {
    $rel = $f.FullName.Substring($TemplatePath.TrimEnd('\').Length + 1)
    New-Object psobject -Property @{ Source = $f.FullName; Rel = (Get-RelativeDestination $rel) }
}
$dirs = @($manifest.directories) | Where-Object { $_ } | ForEach-Object { $_ -replace '/', '\' }

$longest = 0
foreach ($rel in @($plan | ForEach-Object { $_.Rel }) + $dirs) {
    $len = (Join-Path $labPath $rel).Length
    if ($len -gt $longest) { $longest = $len }
}
if ($longest -gt 248) {
    Stop-Lab 'error' 1 "The destination path is too long for the LAB structure ($longest characters, max 248). Choose a shorter folder."
    return (Complete-Lab)
}

# ---- Existing LAB? ----------------------------------------------------------
$marker = $null
if (Test-Path -LiteralPath $labPath -PathType Leaf) {
    Stop-Lab 'error' 1 "A file named '$Name' already exists in $rootFull."; return (Complete-Lab)
}
if (Test-Path -LiteralPath $labPath -PathType Container) {
    $markerPath = Join-Path $labPath $MarkerName
    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        try { $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json } catch { $marker = $null }
        if (-not $marker -or $marker.tool -ne $ToolId) {
            Stop-Lab 'conflict' 2 "$markerPath exists but is not a valid Vorterm LAB marker. Nothing was changed."
            return (Complete-Lab)
        }
        $result.Mode = 'update'
    } elseif (@(Get-ChildItem -LiteralPath $labPath -Force | Select-Object -First 1).Count -eq 0) {
        $result.Mode = 'new'
    } elseif ($Adopt) {
        $result.Mode = 'adopt'
    } else {
        Stop-Lab 'conflict' 2 "$labPath already exists and was not created by Vorterm. Choose another location or use -Adopt to add only the missing files."
        return (Complete-Lab)
    }
    $writeErr = Test-WriteAccess $labPath
} else {
    $result.Mode = 'new'
    $writeErr = Test-WriteAccess $rootFull
}
if ($writeErr) {
    Stop-Lab 'error' 1 "No write permission in the destination: $writeErr"
    return (Complete-Lab)
}

if ($ValidateOnly) { return (Complete-Lab) }

# ---- Apply ------------------------------------------------------------------
$recorded = @{}
if ($marker -and $marker.files) {
    foreach ($prop in $marker.files.PSObject.Properties) { $recorded[$prop.Name] = [string]$prop.Value }
}
$newRecord = @{}

$allDirs = @($dirs) + @($plan | ForEach-Object { Split-Path $_.Rel -Parent } | Where-Object { $_ }) | Sort-Object -Unique
foreach ($d in @('') + $allDirs) {
    $full = if ($d) { Join-Path $labPath $d } else { $labPath }
    if (Test-Path -LiteralPath $full -PathType Container) { continue }
    try {
        if (-not $DryRun) { [void][IO.Directory]::CreateDirectory($full) }
        if ($d) { $result.Directories += $d }
    } catch {
        $result.Errors += "folder ${d}: $($_.Exception.Message)"
    }
}

foreach ($item in $plan) {
    $key  = $item.Rel -replace '\\', '/'
    $dest = Join-Path $labPath $item.Rel
    try {
        $srcHash = Get-Sha256 $item.Source
        if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) {
            if (-not $DryRun) { [IO.File]::Copy($item.Source, $dest, $false) }
            $result.Created += $key
            $newRecord[$key] = $srcHash
            continue
        }
        $destHash = Get-Sha256 $dest
        if ($destHash -eq $srcHash) {
            $result.Unchanged += $key
            $newRecord[$key] = $srcHash
        } elseif ($result.Mode -eq 'update' -and $recorded.ContainsKey($key) -and $recorded[$key] -eq $destHash) {
            if (-not $DryRun) { [IO.File]::Copy($item.Source, $dest, $true) }
            $result.Updated += $key
            $newRecord[$key] = $srcHash
        } else {
            $result.Kept += $key
            if ($recorded.ContainsKey($key)) { $newRecord[$key] = $recorded[$key] }
        }
    } catch {
        $result.Errors += "${key}: $($_.Exception.Message)"
    }
}

if (-not $DryRun) {
    $now = (Get-Date).ToString('s')
    $created = if ($marker -and $marker.created) { [string]$marker.created } else { $now }
    $markerObj = [ordered]@{
        tool            = $ToolId
        templateVersion = $result.Version
        created         = $created
        updated         = $now
        note            = 'Written by Vorterm. Lets a later run update files you have not changed. Safe to keep in git.'
        files           = $newRecord
    }
    try {
        $json = $markerObj | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText((Join-Path $labPath $MarkerName), $json, (New-Object Text.UTF8Encoding $false))
    } catch {
        $result.Errors += "marker: $($_.Exception.Message)"
    }
}

if ($result.Errors.Count -gt 0) {
    $result.Status = 'partial'
    $result.ExitCode = 3
}
return (Complete-Lab)
