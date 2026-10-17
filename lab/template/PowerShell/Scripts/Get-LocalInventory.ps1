<#
.SYNOPSIS
    READ-ONLY. Hardware, operating system, disk and network summary of the local computer.

.DESCRIPTION
    Example of the lab script standard that works on any Windows machine without modules,
    sign-in or administrator rights. Prints a summary and can export it as JSON.

.PARAMETER ExportJson
    Also write the inventory to exports/local-inventory-<computer>-YYYYMMDD-HHMM.json.

.EXAMPLE
    .\Get-LocalInventory.ps1

.EXAMPLE
    .\Get-LocalInventory.ps1 -ExportJson

.NOTES
    Context: user. Permissions: none. Modules: none (CIM, built in).
#>
[CmdletBinding()]
param(
    [switch]$ExportJson
)

$ErrorActionPreference = 'Stop'

$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios = Get-CimInstance Win32_BIOS

$disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    New-Object psobject -Property ([ordered]@{
        Drive   = $_.DeviceID
        SizeGB  = [math]::Round($_.Size / 1GB, 1)
        FreeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
        FreePct = if ($_.Size) { [math]::Round(100 * $_.FreeSpace / $_.Size, 0) } else { 0 }
    })
}

$nics = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' | ForEach-Object {
    New-Object psobject -Property ([ordered]@{
        Adapter = $_.Description
        IPv4    = ($_.IPAddress | Where-Object { $_ -match '^\d+\.' }) -join ', '
        Gateway = ($_.DefaultIPGateway) -join ', '
        DNS     = ($_.DNSServerSearchOrder) -join ', '
    })
}

$inventory = New-Object psobject -Property ([ordered]@{
    Computer     = $env:COMPUTERNAME
    Collected    = (Get-Date).ToString('s')
    OS           = $os.Caption
    Version      = $os.Version
    Build        = $os.BuildNumber
    LastBoot     = $os.LastBootUpTime
    Manufacturer = $cs.Manufacturer
    Model        = $cs.Model
    Serial       = $bios.SerialNumber
    CPU          = $cpu.Name
    MemoryGB     = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    Disks        = @($disks)
    Network      = @($nics)
})

$inventory | Select-Object Computer, OS, Version, Build, LastBoot, Manufacturer, Model, CPU, MemoryGB | Format-List
$disks | Format-Table -AutoSize
$nics  | Format-Table -AutoSize

if ($ExportJson) {
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $dir  = Join-Path $root 'exports'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $out  = Join-Path $dir ('local-inventory-{0}-{1}.json' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmm'))
    $inventory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $out -Encoding UTF8
    Write-Host "Exported: $out"
}
