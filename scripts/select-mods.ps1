param(
    [string] $BaseRef,
    [string] $HeadRef = 'HEAD',
    [string[]] $Mod,
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Import-Module (Join-Path $PSScriptRoot 'ModBuild.psm1') -Force

$headCommit = Invoke-RepositoryGit $RepositoryRoot @('rev-parse', '--verify', "${HeadRef}^{commit}")
$headFiles = @(Invoke-RepositoryGit $RepositoryRoot @('ls-tree', '-r', '--name-only', $headCommit))
$metadataPaths = @($headFiles | Where-Object { $_ -match '^[^/]+/info\.json$' })
$baseFiles = @()
if ($BaseRef -match '^0{40}$') {
    $baseFiles = @()
} elseif (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
    $baseCommit = Invoke-RepositoryGit $RepositoryRoot @('rev-parse', '--verify', "${BaseRef}^{commit}")
    $baseFiles = @(Invoke-RepositoryGit $RepositoryRoot @('ls-tree', '-r', '--name-only', $baseCommit))
} elseif ($Mod.Count -eq 0) {
    throw 'Pass -BaseRef to compare versions, or -Mod to select mods explicitly.'
}

$selected = @()
foreach ($path in $metadataPaths) {
    $name = $path.Split('/')[0]
    if ($headFiles -cnotcontains "$name/$name.mod") {
        continue
    }
    if ($Mod.Count -gt 0 -and $Mod -inotcontains $name) {
        continue
    }
    $information = (Invoke-RepositoryGit $RepositoryRoot @('show', "${headCommit}:$path")) -join "`n" |
        ConvertFrom-Json -AsHashtable
    if ($Mod.Count -eq 0 -and $baseFiles -ccontains $path) {
        $previous = (Invoke-RepositoryGit $RepositoryRoot @('show', "${baseCommit}:$path")) -join "`n" |
            ConvertFrom-Json -AsHashtable
        if ($previous['version'] -ceq $information['version']) {
            continue
        }
    }
    $build = Get-ModBuildInfo -RepositoryRoot $RepositoryRoot -Name $name -Information $information
    if (-not $build.enabled) {
        if ($Mod.Count -gt 0) {
            throw "Build is disabled in $name/info.json"
        }
        continue
    }
    $selected += $build
}

foreach ($name in $Mod) {
    if ($selected.mod -inotcontains $name) {
        throw "Mod is not present in ${HeadRef}: $name"
    }
}

ConvertTo-Json -InputObject @{ include = @($selected) } -Depth 5 -Compress
