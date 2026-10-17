<#
.SYNOPSIS
    WRITE (local files only). Creates a new LAB document from a template in Templates/.

.DESCRIPTION
    Copies the template for the chosen type, replaces {{TITLE}} and {{DATE}}, and saves it
    in the conventional folder of the area. Never overwrites an existing file. Does not
    connect to any service.

.PARAMETER Type
    runbook | change | incident | postmortem | investigation | project | handoff

.PARAMETER Title
    Human title. The file name is derived from it (lowercase, ASCII, dashes).

.PARAMETER Area
    Top-level LAB folder (Azure, Microsoft365, Outlook, Intune, Cybersecurity,
    PowerAutomate, CloudOps, PowerShell, DevOps, Documentation). Default depends on type.

.PARAMETER Date
    Date used in the file name and content. Default: today (yyyy-MM-dd).

.EXAMPLE
    .\New-LabItem.ps1 -Type runbook -Area CloudOps -Title 'Rotate storage keys'

.EXAMPLE
    .\New-LabItem.ps1 -Type project -Area Azure -Title 'Landing zone review'

.NOTES
    Context: user. Permissions: write access to the LAB folder. Modules: none.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('runbook', 'change', 'incident', 'postmortem', 'investigation', 'project', 'handoff')]
    [string]$Type,
    [Parameter(Mandatory = $true)][string]$Title,
    [string]$Area,
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$labRoot   = Split-Path -Parent $PSScriptRoot
$templates = Join-Path $labRoot 'Templates'

function ConvertTo-Slug {
    param([string]$Text)
    $norm = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $norm.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    $slug = ($sb.ToString().ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    if (-not $slug) { throw "The title '$Text' does not produce a usable file name." }
    return $slug
}

$defaults = @{
    runbook = 'CloudOps'; change = 'CloudOps'; incident = 'Cybersecurity'; postmortem = 'Documentation'
    investigation = 'Cybersecurity'; project = 'CloudOps'; handoff = ''
}
if (-not $PSBoundParameters.ContainsKey('Area')) { $Area = $defaults[$Type] }
if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "Date must be yyyy-MM-dd (got: $Date)." }

if ($Area) {
    $areaPath = Join-Path $labRoot $Area
    if (-not (Test-Path -LiteralPath $areaPath -PathType Container) -or $Area -match '[\\/]' -or $Area -like '.*') {
        $areas = Get-ChildItem -LiteralPath $labRoot -Directory |
            Where-Object { $_.Name -notmatch '^(\.|Templates$|Tools$|config$|exports$|logs$|evidence$)' } |
            Select-Object -ExpandProperty Name
        throw "Unknown area '$Area'. Available: $($areas -join ', ')"
    }
} else {
    $areaPath = $labRoot
}

$slug = ConvertTo-Slug $Title
$files = @()
switch ($Type) {
    'runbook'       { $files += @{ T = 'runbook.md';             D = Join-Path $areaPath "Runbooks\$slug.md" } }
    'change'        { $files += @{ T = 'change-plan.md';         D = Join-Path $areaPath "Changes\$Date-$slug.md" } }
    'incident'      { $files += @{ T = 'incident.md';            D = Join-Path $areaPath "Incidents\$Date-$slug.md" } }
    'postmortem'    { $files += @{ T = 'postmortem.md';          D = Join-Path $areaPath "Reports\$Date-postmortem-$slug.md" } }
    'investigation' { $files += @{ T = 'investigation-notes.md'; D = Join-Path $areaPath "Investigations\$Date-$slug.md" } }
    'handoff'       { $files += @{ T = 'context-handoff.md';     D = Join-Path $areaPath "HANDOFF-$Date-$slug.md" } }
    'project' {
        $proj = Join-Path $areaPath "Projects\$Date-$slug"
        $files += @{ T = 'project-brief.md'; D = Join-Path $proj 'README.md' }
        $files += @{ T = '';                 D = Join-Path $proj 'TODO.md' }
    }
}

foreach ($f in $files) {
    if (Test-Path -LiteralPath $f.D) { throw "Already exists, nothing was changed: $($f.D)" }
}

$utf8 = New-Object Text.UTF8Encoding $false
foreach ($f in $files) {
    $dir = Split-Path -Parent $f.D
    if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    if ($f.T) {
        $src = Join-Path $templates $f.T
        if (-not (Test-Path -LiteralPath $src)) { throw "Template not found: $src" }
        $text = [IO.File]::ReadAllText($src)
    } else {
        $text = "# TODO - $Title`r`n`r`nUpdated: $Date`r`n`r`n## Blocked on a person`r`n`r`n- [ ] `r`n`r`n## Next steps`r`n`r`n- [ ] `r`n"
    }
    $text = $text.Replace('{{TITLE}}', $Title).Replace('{{DATE}}', $Date)
    [IO.File]::WriteAllText($f.D, $text, $utf8)
    Write-Host "Created: $($f.D)"
}
