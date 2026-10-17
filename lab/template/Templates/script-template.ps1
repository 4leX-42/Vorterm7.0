<#
.SYNOPSIS
    WRITE (dry-run by default). <One line: what this script changes and where.>
    For read-only scripts start the line with "READ-ONLY." and remove -Execute.

.DESCRIPTION
    <What it does, in which order, and what it never does.>

.PARAMETER Target
    <Replace with the real parameters. Everything that varies is a parameter.>

.PARAMETER Execute
    Apply the changes. Without it the script reads, saves a snapshot and prints the plan.

.PARAMETER Requester
    Who asked for the change (goes to the transcript).

.PARAMETER Reason
    Ticket number or reason (goes to the transcript).

.EXAMPLE
    .\Verb-Noun.ps1 -Target 'example'             # dry run
    .\Verb-Noun.ps1 -Target 'example' -Execute    # apply

.NOTES
    Context    : user | admin | SYSTEM
    Permissions: <roles, Graph scopes or RBAC needed>
    Modules    : <modules and minimum versions>
    Rollback   : <how to undo, using the snapshot written to exports/>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Target,
    [switch]$Execute,
    [string]$Requester = $env:USERNAME,
    [string]$Reason = ''
)

$ErrorActionPreference = 'Stop'

function Get-LabRoot {
    $d = $PSScriptRoot
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d '.vorterm-lab.json')) { return $d }
        $d = Split-Path -Parent $d
    }
    return $PSScriptRoot
}

$labRoot = Get-LabRoot
$stamp   = Get-Date -Format 'yyyyMMdd-HHmm'
$name    = [IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
foreach ($d in 'logs', 'exports') {
    $p = Join-Path $labRoot $d
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}
$transcript = Join-Path $labRoot "logs\$stamp-$name.log"
Start-Transcript -LiteralPath $transcript | Out-Null

try {
    Write-Host ("{0} | target={1} | execute={2} | requester={3} | reason={4}" -f $name, $Target, [bool]$Execute, $Requester, $Reason)

    # 1. Read the current state (read-only). Replace with the real query.
    $current = @()
    Write-Host "Objects in scope: $($current.Count)"

    # 2. Snapshot before any change. This file is the rollback source.
    $snapshot = Join-Path $labRoot "exports\$name-before-$stamp.csv"
    $current | Export-Csv -LiteralPath $snapshot -NoTypeInformation -Encoding UTF8
    Write-Host "Snapshot: $snapshot"

    # 3. Plan: show exactly what would change.
    foreach ($item in $current) {
        Write-Host "[PLAN] would change: $item"
    }

    if (-not $Execute) {
        Write-Host 'Dry run: nothing was changed. Re-run with -Execute to apply.' -ForegroundColor Yellow
        return
    }

    # 4. Apply. One object at a time, stop on the first error.
    foreach ($item in $current) {
        # <change here>
        Write-Host "[DONE] $item"
    }

    # 5. Verify by reading the result back. "No error" is not proof.
    # $after = <same query as step 1>
    # Write-Host "Before: $($current.Count)  After: $($after.Count)"
}
finally {
    Stop-Transcript | Out-Null
}
