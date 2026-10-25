param(
    [Parameter(Mandatory)][string[]] $Mod,
    [Parameter(Mandatory)][securestring] $ApiKey,
    [string] $OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'output'),
    [string] $MainRef,
    [string] $RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Import-Module (Join-Path $PSScriptRoot 'ModBuild.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ModRelease.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'NexusApi.psm1') -Force

function Get-NexusMainFile {
    param([hashtable] $Client, [string] $ModId)

    $result = Invoke-NexusApi $Client GET "/mods/$ModId/files"
    $files = @($result.mod_files)
    if ($files.Count -eq 0) {
        return
    }
    $candidates = @(
        foreach ($file in $files) {
            if (-not $file.is_active) {
                continue
            }
            $fileId = [uri]::EscapeDataString($file.id)
            $result = Invoke-NexusApi $Client GET "/mod-files/$fileId/versions"
            $mainVersions = @($result.versions | Where-Object { $_.category -ceq 'main' })
            if ($mainVersions.Count -gt 0) {
                [pscustomobject]@{
                    id = $fileId
                    name = $file.name
                    versions = @($result.versions)
                    latest = $mainVersions | Sort-Object { [decimal] $_.position } -Descending | Select-Object -First 1
                }
            }
        }
    )
    if ($candidates.Count -ne 1) {
        throw "Expected one MAIN file group on Nexus mod $ModId; found $($candidates.Count). Other file groups will not be changed."
    }
    return $candidates[0]
}

function Publish-ModPackage {
    param([hashtable] $Client, [object] $Release, [string] $Path)

    $details = Invoke-NexusApi $Client GET "/games/$($Release.game)/mods/$($Release.nexus_id)"
    $modId = [uri]::EscapeDataString($details.id)
    $main = Get-NexusMainFile $Client $modId
    $existing = @()
    $name = $Release.name
    if ($null -ne $main) {
        $name = $main.name
        $matching = @($main.versions | Where-Object { $_.version -ceq $Release.version })
        $existing = @($matching | Where-Object { $_.category -ceq 'main' })
        if ($matching.Count -gt 0 -and $existing.Count -eq 0) {
            $categories = ($matching.category | Sort-Object -Unique) -join ', '
            throw "Nexus version $($Release.version) exists only in non-MAIN categories ($categories); no ZIP will be uploaded."
        }
        if ([semver] $Release.version -lt [semver] $main.latest.version) {
            throw "Refusing to replace Nexus version $($main.latest.version) with $($Release.version)."
        }
    }
    if ($name -cnotmatch "^[a-zA-Z0-9_'().-]{1,50}$") {
        throw "Invalid Nexus file name: $name"
    }

    $history = Invoke-NexusApi -Client $Client -Method GET -Version v1 `
        -Path "/games/$($Release.game)/mods/$($Release.nexus_id)/changelogs.json"
    if ($history -isnot [Collections.IDictionary]) {
        throw "Nexus returned an invalid changelog for $($Release.mod)."
    }
    $written = @()
    if ($history.Contains($Release.version)) {
        $written = @($history[$Release.version])
    }
    if ($written.Count -gt $Release.entries.Count) {
        throw "Nexus changelog contains more entries than CHANGELOG.md for $($Release.mod) $($Release.version)."
    }
    for ($index = 0; $index -lt $written.Count; $index++) {
        if ($written[$index] -isnot [string] -or $written[$index] -cne $Release.entries[$index]) {
            throw "Nexus changelog differs from CHANGELOG.md for $($Release.mod) $($Release.version); no entries will be appended."
        }
    }
    foreach ($entry in $Release.entries) {
        if ($entry.Length -gt 65535) {
            throw "Changelog entry exceeds the Nexus limit for $($Release.mod)."
        }
    }

    if ($existing.Count -eq 0) {
        $body = @{
            upload_id = Send-NexusUpload $Client $Path
            name = $name
            version = $Release.version
            file_category = 'main'
            update_mod_version = $true
        }
        if ($null -eq $main) {
            $body.mod_id = $details.id
            $created = Invoke-NexusApi $Client POST '/mod-files' $body
            Write-Host "Created MAIN file $($created.id) for $($Release.mod) $($Release.version)."
        } else {
            $body.archive_existing_file = $false
            $body.previous_version_id = $main.latest.id
            $created = Invoke-NexusApi $Client POST "/mod-files/$($main.id)/versions" $body
            Write-Host "Created file version $($created.version.id) for $($Release.mod) $($Release.version)."
        }
    } else {
        Write-Host "$($Release.mod) $($Release.version) already exists; the ZIP will not be uploaded again."
    }

    # Each plain-text item is one append request; newline splitting is not assumed.
    for ($index = $written.Count; $index -lt $Release.entries.Count; $index++) {
        $entry = $Release.entries[$index]
        $added = Invoke-NexusApi $Client POST "/mods/$modId/changelogs" @{
            version = $Release.version
            changelog = $entry
        }
        if ($added.version -cne $Release.version -or $added.changelog -cne $entry) {
            throw 'Nexus did not confirm the requested changelog entry. Check the result before retrying.'
        }
        Write-Host "Changelog entry $($index + 1)/$($Release.entries.Count) saved for $($Release.mod)."
    }
    Write-Host "Published $($Release.mod) $($Release.version)."
}

if ($MainRef) {
    $sourceCommit = Invoke-RepositoryGit $RepositoryRoot @('rev-parse', '--verify', 'HEAD')
    $mergeBases = @(Invoke-RepositoryGit $RepositoryRoot @('merge-base', '--all', 'HEAD', $MainRef))
    if ($mergeBases -cnotcontains $sourceCommit) {
        Write-Host 'Skipping publication: the source commit is no longer part of main.'
        return
    }
}

$client = New-NexusClient $ApiKey
$failures = [Collections.Generic.List[string]]::new()
foreach ($name in $Mod) {
    try {
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "Invalid mod directory name: $name"
        }
        $path = Join-Path $OutputDirectory "$name.zip"
        $release = Get-ModReleasePackage $name $path
        if ($null -eq $release) {
            Write-Host "Skipping ${name}: publishing is disabled or no Nexus homepage is configured."
            continue
        }
        if ($MainRef) {
            $metadataPath = "$name/info.json"
            $tracked = @(Invoke-RepositoryGit $RepositoryRoot @('ls-tree', '--name-only', $MainRef, '--', $metadataPath))
            if ($tracked.Count -eq 0) {
                Write-Host "Skipping ${name}: its metadata is no longer present on main."
                continue
            }
            $current = (Invoke-RepositoryGit $RepositoryRoot @('show', "${MainRef}:$metadataPath")) -join "`n" |
                ConvertFrom-Json -AsHashtable
            $latest = Get-ModReleaseInfo $name $current
            if ($null -eq $latest -or $latest.version -cne $release.version -or
                $latest.game -cne $release.game -or $latest.nexus_id -cne $release.nexus_id) {
                Write-Host "Skipping ${name}: its release version or destination has changed on main."
                continue
            }
        }
        Publish-ModPackage $client $release $path
    }
    catch {
        # Preserve independent releases while reporting the overall run as failed.
        $failures.Add($name)
        Write-Error -Message "${name}: $($_.Exception.Message)" -ErrorAction Continue
    }
}
if ($failures.Count -gt 0) {
    throw "Nexus publishing failed for: $($failures -join ', ')"
}
