<#
.SYNOPSIS
    READ-ONLY. EXAMPLE. Counts resources per type and location in the current Azure subscription.

.DESCRIPTION
    Example of the lab script standard for a read-only Azure script. It uses the session you
    already opened with Connect-AzAccount; it never signs in and never changes anything.
    Optional CSV export to exports/.

.PARAMETER SubscriptionId
    Subscription to read. Default: the subscription of the current Az context.

.PARAMETER ExportCsv
    Also write the summary to exports/azure-resource-summary-YYYYMMDD-HHMM.csv.

.EXAMPLE
    .\EXAMPLE-Get-AzResourceSummary.ps1

.NOTES
    Context: user. Permissions: Reader on the subscription. Modules: Az.Accounts, Az.Resources.
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [switch]$ExportCsv
)

$ErrorActionPreference = 'Stop'

foreach ($m in 'Az.Accounts', 'Az.Resources') {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        throw "Module $m is not installed. Install-Module $m -Scope CurrentUser"
    }
}

$ctx = Get-AzContext
if (-not $ctx) { throw 'No Azure session. Run Connect-AzAccount first (this script never signs in).' }
if ($SubscriptionId -and $ctx.Subscription.Id -ne $SubscriptionId) {
    $ctx = Set-AzContext -SubscriptionId $SubscriptionId
}
Write-Host ("Subscription: {0} ({1})" -f $ctx.Subscription.Name, $ctx.Subscription.Id)

$summary = Get-AzResource |
    Group-Object ResourceType, Location |
    ForEach-Object {
        New-Object psobject -Property ([ordered]@{
            ResourceType = $_.Group[0].ResourceType
            Location     = $_.Group[0].Location
            Count        = $_.Count
        })
    } |
    Sort-Object Count -Descending

$summary | Format-Table -AutoSize

if ($ExportCsv) {
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $out  = Join-Path $root ('exports\azure-resource-summary-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmm'))
    $summary | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
    Write-Host "Exported: $out"
}
