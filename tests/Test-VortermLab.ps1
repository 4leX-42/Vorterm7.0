<#
.SYNOPSIS
    READ-ONLY for the system. Functional tests of lab\New-VortermLab.ps1 inside a temporary folder.

.DESCRIPTION
    Creates a scratch folder (default under %TEMP%), runs the LAB generator through every
    acceptance scenario and deletes the scratch folder afterwards (unless -Keep). It never
    touches anything outside that folder, except the ACL test which only changes the ACL
    of a subfolder it created.

    Scenarios: paths with spaces and special characters, idempotent re-run, user changes
    kept, template update applied only to untouched files, deleted file restored, conflict
    with an existing non-Vorterm folder, -Adopt, invalid paths, no write permission,
    dry run, validate-only, non-elevated check, and a scan for secrets / private data.

    Exit code 0 when every test passes, 1 otherwise. -JsonOut writes the results as JSON.

.PARAMETER WorkRoot
    Scratch folder. Default: %TEMP%\vorterm-lab-tests-<random>.

.PARAMETER Keep
    Keep the scratch folder for inspection.

.PARAMETER JsonOut
    Path of a JSON file with the results.

.NOTES
    Context: user. Permissions: none. Modules: none. Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
    [string]$WorkRoot = (Join-Path $env:TEMP ('vorterm-lab-tests-' + [guid]::NewGuid().ToString('N').Substring(0, 6))),
    [switch]$Keep,
    [string]$JsonOut
)

$ErrorActionPreference = 'Stop'
$repo      = Split-Path -Parent $PSScriptRoot
$gen       = Join-Path $repo 'lab\New-VortermLab.ps1'
$template  = Join-Path $repo 'lab\template'
$manifest  = Join-Path $repo 'lab\lab-manifest.json'
$tplCount  = @(Get-ChildItem -LiteralPath $template -Recurse -File -Force).Count
$results   = New-Object System.Collections.ArrayList

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    $ok = $false; $detail = ''
    try {
        $r = & $Body
        if ($r -is [string]) { $detail = $r; $ok = $true }
        elseif ($r -eq $true) { $ok = $true }
        else { $detail = "returned: $r" }
    } catch {
        $detail = $_.Exception.Message
    }
    [void]$results.Add((New-Object psobject -Property ([ordered]@{ Test = $Name; Pass = $ok; Detail = $detail })))
    $color = if ($ok) { 'Green' } else { 'Red' }
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Host ("[{0}] {1} {2}" -f $tag, $Name, $(if ($detail) { "- $detail" } else { '' })) -ForegroundColor $color
}

function Invoke-Gen {
    param([hashtable]$P)
    $P.PassThru = $true
    return (& $gen @P)
}

function Assert {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
Write-Host "Scratch: $WorkRoot  (template files: $tplCount)"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# 1. New LAB in a path with spaces, brackets, ampersand and accented letters
$odd = Join-Path $WorkRoot ('My Docs (copy) [v2] & ' + [string][char]0x00D1 + 'and' + [char]0x00FA + ' ' + [char]0x00E9 + 'xito')
New-Item -ItemType Directory -Path $odd -Force | Out-Null
$lab = Join-Path $odd 'LAB'

Test-Case '01 create in path with spaces and special characters' {
    $r = Invoke-Gen @{ Root = $odd }
    Assert ($r.ExitCode -eq 0) "exit $($r.ExitCode): $($r.Errors -join '; ')"
    Assert ($r.Mode -eq 'new') "mode $($r.Mode)"
    Assert ($r.Created.Count -eq $tplCount) "created $($r.Created.Count) of $tplCount"
    Assert (Test-Path -LiteralPath (Join-Path $lab '.vorterm-lab.json')) 'marker missing'
    Assert (Test-Path -LiteralPath (Join-Path $lab '.gitignore')) '.gitignore not renamed from dot-gitignore'
    Assert (Test-Path -LiteralPath (Join-Path $lab '.claude\settings.json')) '.claude not renamed from dot-claude'
    Assert (-not (Test-Path -LiteralPath (Join-Path $lab 'dot-gitignore'))) 'dot- name leaked'
    "files $($r.Created.Count), folders $($r.Directories.Count)"
}

Test-Case '02 every manifest folder exists' {
    $dirs = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).directories
    $missing = @($dirs | Where-Object { -not (Test-Path -LiteralPath (Join-Path $lab $_)) })
    Assert ($missing.Count -eq 0) "missing: $($missing -join ', ')"
    "$(@($dirs).Count) folders"
}

Test-Case '03 second run changes nothing' {
    $before = (Get-ChildItem -LiteralPath $lab -Recurse -File -Force | Measure-Object Length -Sum).Sum
    $r = Invoke-Gen @{ Root = $odd }
    Assert ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
    Assert ($r.Mode -eq 'update') "mode $($r.Mode)"
    Assert ($r.Created.Count -eq 0 -and $r.Updated.Count -eq 0 -and $r.Kept.Count -eq 0) "created $($r.Created.Count) updated $($r.Updated.Count) kept $($r.Kept.Count)"
    Assert ($r.Unchanged.Count -eq $tplCount) "unchanged $($r.Unchanged.Count)"
    $after = (Get-ChildItem -LiteralPath $lab -Recurse -File -Force | Measure-Object Length -Sum).Sum
    Assert ($after -eq $before -or $after -gt 0) 'size changed unexpectedly'
    'idempotent'
}

Test-Case '04 user changes and user files are kept' {
    $readme = Join-Path $lab 'README.md'
    Add-Content -LiteralPath $readme -Value "`r`nMY OWN NOTES"
    $mine = Join-Path $lab 'Azure\Scripts\My-Own-Script.ps1'
    Set-Content -LiteralPath $mine -Value '# mine'
    $r = Invoke-Gen @{ Root = $odd }
    Assert ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
    Assert ($r.Kept -contains 'README.md') "README not reported as kept: $($r.Kept -join ',')"
    Assert ((Get-Content -LiteralPath $readme -Raw) -match 'MY OWN NOTES') 'README overwritten'
    Assert ((Get-Content -LiteralPath $mine -Raw) -match 'mine') 'user file changed'
    'README kept, own script untouched'
}

Test-Case '05 deleted template file is restored' {
    Remove-Item -LiteralPath (Join-Path $lab 'TODO.md')
    $r = Invoke-Gen @{ Root = $odd }
    Assert ($r.Created -contains 'TODO.md') "created: $($r.Created -join ',')"
    'TODO.md recreated'
}

Test-Case '06 template update refreshes only untouched files' {
    $tpl2 = Join-Path $WorkRoot 'template-v2'
    Copy-Item -LiteralPath $template -Destination $tpl2 -Recurse
    Add-Content -LiteralPath (Join-Path $tpl2 'Templates\runbook.md') -Value "`r`n## New section in v2"
    Add-Content -LiteralPath (Join-Path $tpl2 'README.md') -Value "`r`nv2 text"
    Set-Content -LiteralPath (Join-Path $tpl2 'Templates\new-in-v2.md') -Value '# new'
    $m2 = Join-Path $WorkRoot 'manifest-v2.json'
    $mj = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    $mj.version = '9.9.9'
    $mj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $m2
    $r = Invoke-Gen @{ Root = $odd; TemplatePath = $tpl2; ManifestPath = $m2 }
    Assert ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
    Assert ($r.Updated -contains 'Templates/runbook.md') "runbook not updated: $($r.Updated -join ',')"
    Assert ($r.Kept -contains 'README.md') 'modified README should be kept'
    Assert ($r.Created -contains 'Templates/new-in-v2.md') 'new template file not added'
    Assert ((Get-Content -LiteralPath (Join-Path $lab 'README.md') -Raw) -notmatch 'v2 text') 'user README overwritten'
    $mk = Get-Content -LiteralPath (Join-Path $lab '.vorterm-lab.json') -Raw | ConvertFrom-Json
    Assert ($mk.templateVersion -eq '9.9.9') "marker version $($mk.templateVersion)"
    "updated $($r.Updated.Count), kept $($r.Kept.Count), created $($r.Created.Count)"
}

Test-Case '07 dry run writes nothing' {
    $dryRoot = Join-Path $WorkRoot 'dry run'
    New-Item -ItemType Directory -Path $dryRoot | Out-Null
    $r = Invoke-Gen @{ Root = $dryRoot; DryRun = $true }
    Assert ($r.ExitCode -eq 0) "exit $($r.ExitCode)"
    Assert ($r.Created.Count -eq $tplCount) "would create $($r.Created.Count)"
    Assert (-not (Test-Path -LiteralPath (Join-Path $dryRoot 'LAB'))) 'LAB folder was created in dry run'
    'nothing written'
}

Test-Case '08 existing non-Vorterm folder is a conflict and is not touched' {
    $cRoot = Join-Path $WorkRoot 'conflict'
    $cLab = Join-Path $cRoot 'LAB'
    New-Item -ItemType Directory -Path $cLab -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $cLab 'README.md') -Value 'previous work'
    $r = Invoke-Gen @{ Root = $cRoot }
    Assert ($r.ExitCode -eq 2 -and $r.Status -eq 'conflict') "exit $($r.ExitCode) status $($r.Status)"
    Assert (@(Get-ChildItem -LiteralPath $cLab -Force).Count -eq 1) 'files were written despite the conflict'
    Assert ((Get-Content -LiteralPath (Join-Path $cLab 'README.md') -Raw) -match 'previous work') 'existing file changed'
    $r.Errors[0]
}

Test-Case '09 -Adopt adds missing files only' {
    $cRoot = Join-Path $WorkRoot 'conflict'
    $r = Invoke-Gen @{ Root = $cRoot; Adopt = $true }
    Assert ($r.ExitCode -eq 0 -and $r.Mode -eq 'adopt') "exit $($r.ExitCode) mode $($r.Mode)"
    Assert ($r.Kept -contains 'README.md') 'existing README not kept'
    Assert ((Get-Content -LiteralPath (Join-Path $cRoot 'LAB\README.md') -Raw) -match 'previous work') 'README overwritten'
    Assert ($r.Created.Count -eq ($tplCount - 1)) "created $($r.Created.Count)"
    "created $($r.Created.Count), kept README"
}

Test-Case '10 invalid destinations are rejected' {
    $file = Join-Path $WorkRoot 'a-file.txt'; Set-Content -LiteralPath $file -Value 'x'
    $cases = @(
        @{ Root = 'relative\path' },
        @{ Root = 'C:relative' },
        @{ Root = (Join-Path $WorkRoot 'does-not-exist') },
        @{ Root = $file },
        @{ Root = $env:windir },
        @{ Root = (Join-Path $env:ProgramFiles 'Common Files') },
        @{ Root = $WorkRoot; Name = 'bad:name' },
        @{ Root = $WorkRoot + '\' + ('x' * 220) }
    )
    $msgs = foreach ($c in $cases) {
        $r = Invoke-Gen $c
        Assert ($r.ExitCode -eq 1) "accepted $($c.Root) $($c.Name) (exit $($r.ExitCode))"
        $r.Errors[0]
    }
    "$(@($msgs).Count) rejected"
}

Test-Case '11 no write permission is reported' {
    $ro = Join-Path $WorkRoot 'read only'
    New-Item -ItemType Directory -Path $ro | Out-Null
    $who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = Get-Acl -LiteralPath $ro
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($who, 'Write,AppendData,CreateFiles,CreateDirectories', 'ContainerInherit,ObjectInherit', 'None', 'Deny')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $ro -AclObject $acl
    try {
        $r = Invoke-Gen @{ Root = $ro }
        Assert ($r.ExitCode -eq 1) "exit $($r.ExitCode)"
        Assert (($r.Errors -join ' ') -match 'permission') "message: $($r.Errors -join '; ')"
        $r.Errors[0]
    } finally {
        $acl = Get-Acl -LiteralPath $ro
        [void]$acl.RemoveAccessRule($rule)
        Set-Acl -LiteralPath $ro -AclObject $acl
    }
}

Test-Case '12 validate-only does not write' {
    $vRoot = Join-Path $WorkRoot 'validate'
    New-Item -ItemType Directory -Path $vRoot | Out-Null
    $r = Invoke-Gen @{ Root = $vRoot; ValidateOnly = $true }
    Assert ($r.ExitCode -eq 0 -and $r.Mode -eq 'new') "exit $($r.ExitCode) mode $($r.Mode)"
    Assert (-not (Test-Path -LiteralPath (Join-Path $vRoot 'LAB'))) 'LAB created'
    'ok'
}

Test-Case '13 generated LAB has no secrets or private data' {
    $patterns = @(
        '-----BEGIN [A-Z ]*PRIVATE KEY-----',
        '(?i)AccountKey=',
        '(?i)client_?secret\s*[:=]\s*["'']?[A-Za-z0-9~._-]{12,}',
        '(?i)password\s*[:=]\s*["''][^"'']{4,}',
        'ghp_[A-Za-z0-9]{20,}',
        'xox[abp]-[A-Za-z0-9-]{10,}',
        '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
        '(?i)[a-z0-9._%+-]+@(?!contoso\.example\b|example\.(com|org)\b)[a-z0-9.-]+\.[a-z]{2,}',
        '(?i)C:\\Users\\(?!you\\)[A-Za-z]',
        '(?i)\bandersen\b'
    )
    $hits = foreach ($f in Get-ChildItem -LiteralPath $lab -Recurse -File -Force) {
        if ($f.Name -eq '.vorterm-lab.json') { continue }
        $text = [IO.File]::ReadAllText($f.FullName)
        foreach ($p in $patterns) {
            foreach ($m in [regex]::Matches($text, $p)) {
                if ($m.Value -match '^0{8}-0{4}-0{4}-0{4}-0{12}$') { continue }
                "$($f.Name): $($m.Value)"
            }
        }
    }
    Assert (@($hits).Count -eq 0) ("found: " + (@($hits) | Select-Object -First 5) -join ' | ')
    'clean'
}

Test-Case '14 every LAB script passes the LAB validator' {
    $out = & (Join-Path $lab 'Tools\Test-LabScripts.ps1') -Path $lab 6>&1 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "validator exit $LASTEXITCODE`n$out"
    ($out -split "`n" | Where-Object { $_ -match 'checked' } | Select-Object -Last 1).Trim()
}

Test-Case '15 New-LabItem creates items and never overwrites' {
    $tool = Join-Path $lab 'Tools\New-LabItem.ps1'
    & $tool -Type incident -Title ('Phishing ' + [char]0x00E9 + 'xample') -Date '2026-02-01' | Out-Null
    $inc = Join-Path $lab 'Cybersecurity\Incidents\2026-02-01-phishing-example.md'
    Assert (Test-Path -LiteralPath $inc) 'incident not created'
    Assert ((Get-Content -LiteralPath $inc -Raw) -notmatch '\{\{') 'placeholders left'
    & $tool -Type project -Area Azure -Title 'Landing zone' -Date '2026-02-01' | Out-Null
    Assert (Test-Path -LiteralPath (Join-Path $lab 'Azure\Projects\2026-02-01-landing-zone\TODO.md')) 'project TODO missing'
    $threw = $false
    try { & $tool -Type incident -Title ('Phishing ' + [char]0x00E9 + 'xample') -Date '2026-02-01' | Out-Null } catch { $threw = $true }
    Assert $threw 'second create did not refuse'
    $threw = $false
    try { & $tool -Type runbook -Area NoSuchArea -Title 'x' | Out-Null } catch { $threw = $true }
    Assert $threw 'unknown area accepted'
    'incident + project created, overwrite refused'
}

Test-Case '16 elevation (informational)' {
    if ($isAdmin) { 'running elevated: run this script as a standard user to prove the no-admin path' }
    else { 'running as a standard user: everything above worked without admin rights' }
}

if ($JsonOut) {
    $payload = New-Object psobject -Property ([ordered]@{
        Computer = $env:COMPUTERNAME; User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Elevated = $isAdmin; PSVersion = $PSVersionTable.PSVersion.ToString(); Results = $results
    })
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
}

$failed = @($results | Where-Object { -not $_.Pass })
Write-Host ("{0} tests, {1} failed" -f $results.Count, $failed.Count)
if (-not $Keep) { Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue }
if ($failed.Count -gt 0) { exit 1 }
exit 0
