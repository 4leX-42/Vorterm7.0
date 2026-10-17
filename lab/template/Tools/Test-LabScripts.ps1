<#
.SYNOPSIS
    READ-ONLY. Checks the LAB PowerShell scripts against the script standard.

.DESCRIPTION
    For every .ps1 / .psm1 / .psd1 under -Path (default: the whole LAB, except exports,
    logs and evidence):
      - parses with PowerShell 7 and with Windows PowerShell 5.1 (when both exist)
      - ASCII only
      - .ps1 header: .SYNOPSIS starting with READ-ONLY or WRITE, and a "Context:" line
      - no Invoke-Expression / iex
    Exit code 1 when an error is found, 0 otherwise. Warnings do not fail.

.PARAMETER Path
    File or folder to check. Default: LAB root.

.EXAMPLE
    .\Test-LabScripts.ps1

.EXAMPLE
    .\Test-LabScripts.ps1 -Path ..\Azure\Scripts\My-Script.ps1

.NOTES
    Context: user. Permissions: none. Modules: none.
#>
[CmdletBinding()]
param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $Path)
} else {
    # -Include is ignored together with -LiteralPath on Windows PowerShell 5.1: filter by extension.
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File |
        Where-Object { @('.ps1', '.psm1', '.psd1') -contains $_.Extension.ToLowerInvariant() -and
                       $_.FullName -notmatch '\\(exports|logs|evidence|\.git)\\' })
}

$findings = New-Object System.Collections.ArrayList
function Add-Finding {
    param([string]$File, [int]$Line, [string]$Level, [string]$Message)
    [void]$findings.Add((New-Object psobject -Property ([ordered]@{
        Level = $Level; File = $File; Line = $Line; Message = $Message
    })))
}

# Parse with the current engine.
foreach ($f in $files) {
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    foreach ($e in $errs) {
        Add-Finding $f.FullName $e.Extent.StartLineNumber 'ERROR' ("parse (PS {0}): {1}" -f $PSVersionTable.PSVersion.Major, $e.Message)
    }
    $calls = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($c in $calls) {
        if (@('Invoke-Expression', 'iex') -contains $c.GetCommandName()) {
            Add-Finding $f.FullName $c.Extent.StartLineNumber 'ERROR' 'Invoke-Expression / iex is not allowed'
        }
    }

    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $start = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $start = 3 }
    $line = 1
    for ($i = $start; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10) { $line++ }
        elseif ($bytes[$i] -gt 127) {
            Add-Finding $f.FullName $line 'ERROR' 'non-ASCII character (breaks on Windows PowerShell 5.1)'
            break
        }
    }

    $text = [IO.File]::ReadAllText($f.FullName)
    if ($f.Extension -eq '.ps1') {
        if ($text -notmatch '(?ms)\.SYNOPSIS\s*\r?\n\s*(READ-ONLY|WRITE)\b') {
            Add-Finding $f.FullName 1 'WARNING' '.SYNOPSIS should start with READ-ONLY or WRITE'
        }
        if ($text -notmatch '(?m)^\s*Context\s*:') {
            Add-Finding $f.FullName 1 'WARNING' '.NOTES should state "Context: user | admin | SYSTEM"'
        }
    }
}

# Parse again with Windows PowerShell 5.1 when running on PowerShell 7.
$winPs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if ($PSVersionTable.PSEdition -eq 'Core' -and (Test-Path -LiteralPath $winPs) -and $files.Count -gt 0) {
    $list = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllLines($list, [string[]]($files | ForEach-Object { $_.FullName }))
        $cmd = @"
`$ErrorActionPreference = 'Stop'
foreach (`$p in [IO.File]::ReadAllLines('$($list -replace "'", "''")')) {
    `$t = `$null; `$e = `$null
    [void][System.Management.Automation.Language.Parser]::ParseFile(`$p, [ref]`$t, [ref]`$e)
    foreach (`$x in `$e) { '{0}|{1}|{2}' -f `$p, `$x.Extent.StartLineNumber, `$x.Message }
}
"@
        $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
        $out = & $winPs -NoProfile -NonInteractive -EncodedCommand $enc 2>&1
        foreach ($o in $out) {
            $parts = ([string]$o) -split '\|', 3
            if ($parts.Count -eq 3) { Add-Finding $parts[0] ([int]$parts[1]) 'ERROR' "parse (PS 5.1): $($parts[2])" }
        }
    } finally {
        Remove-Item -LiteralPath $list -Force -ErrorAction SilentlyContinue
    }
}

$errors = @($findings | Where-Object { $_.Level -eq 'ERROR' })
if ($findings.Count -eq 0) {
    Write-Host ("OK: {0} script(s) checked, no findings." -f $files.Count) -ForegroundColor Green
} else {
    $findings | Sort-Object Level, File, Line | Format-Table -AutoSize -Wrap
    Write-Host ("{0} script(s) checked: {1} error(s), {2} warning(s)." -f $files.Count, $errors.Count, ($findings.Count - $errors.Count))
}
if ($errors.Count -gt 0) { exit 1 }
exit 0
