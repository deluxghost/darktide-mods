Set-StrictMode -Version Latest

function Test-ModNexusHomepage {
    param([hashtable] $Information)

    return $Information['homepage'] -is [string] -and
        $Information['homepage'] -match '^https://www\.nexusmods\.com/'
}

function Get-ModReleaseInfo {
    param([string] $Name, [hashtable] $Information)

    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        throw "Invalid mod directory name: $Name"
    }
    if ($Information.ContainsKey('_build') -and $Information['_build']['enabled'] -eq $false) {
        return
    }
    if (-not (Test-ModNexusHomepage $Information)) {
        return
    }
    $uri = [uri] $Information['homepage']
    if ($uri.Scheme -cne 'https' -or $uri.AbsolutePath -notmatch '^/(?<game>[a-z0-9_-]+)/mods/(?<id>[1-9][0-9]*)/?$') {
        throw "Invalid Nexus homepage in $Name/info.json"
    }
    $game = $Matches['game']
    $nexusId = $Matches['id']
    $version = $Information['version']
    if ($version -isnot [string] -or $version -cnotmatch '^[A-Za-z0-9.-]{1,50}$') {
        throw "Invalid Nexus version in $Name/info.json"
    }
    return [pscustomobject]@{
        mod = $Name
        version = $version
        game = $game
        nexus_id = $nexusId
        name = $Information['name'] -replace '\s', ''
    }
}

function Get-ModChangelog {
    param([string] $Text, [string] $Version)

    $lines = $Text -split '\r?\n'
    if ($lines[0] -cne '# Changelog') {
        throw 'CHANGELOG.md must start with # Changelog.'
    }
    $sections = [Collections.Generic.Dictionary[string, Collections.Generic.List[string]]]::new([StringComparer]::Ordinal)
    $current = $null
    for ($index = 1; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -ceq '') {
            continue
        }
        if ($line -cmatch '^## ([A-Za-z0-9][A-Za-z0-9.-]{0,49})$') {
            $heading = $Matches[1]
            if ($sections.ContainsKey($heading)) {
                throw "Duplicate changelog version: $heading"
            }
            if ($null -ne $current -and $current.Count -eq 0) {
                throw "Empty changelog section before line $($index + 1)."
            }
            $current = [Collections.Generic.List[string]]::new()
            $sections.Add($heading, $current)
            continue
        }
        if ($null -eq $current -or $line -cnotmatch '^- (\S(?:.*\S)?)$') {
            throw "Invalid CHANGELOG.md content at line $($index + 1); expected a version heading or a single-line - entry."
        }
        $current.Add($Matches[1])
    }
    if ($null -ne $current -and $current.Count -eq 0) {
        throw 'The last changelog section is empty.'
    }
    if (-not $sections.ContainsKey($Version)) {
        throw "CHANGELOG.md has no entry for version $Version."
    }
    return $sections[$Version].ToArray()
}

function Get-ModReleasePackage {
    param([string] $Name, [string] $Path)

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $archive.GetEntry("$Name/info.json")
        if ($null -eq $entry) {
            throw "Package has no $Name/info.json: $Path"
        }
        $reader = [IO.StreamReader]::new($entry.Open(), [Text.UTF8Encoding]::new($false, $true))
        try {
            $information = $reader.ReadToEnd() | ConvertFrom-Json -AsHashtable
        }
        finally {
            $reader.Dispose()
        }
        $release = Get-ModReleaseInfo $Name $information
        if ($null -eq $release) {
            return
        }
        $entry = $archive.GetEntry("$Name/CHANGELOG.md")
        if ($null -eq $entry) {
            throw "Package has no $Name/CHANGELOG.md: $Path"
        }
        $reader = [IO.StreamReader]::new($entry.Open(), [Text.UTF8Encoding]::new($false, $true))
        try {
            $entries = @(Get-ModChangelog $reader.ReadToEnd() $release.version)
        }
        finally {
            $reader.Dispose()
        }
        $release | Add-Member -NotePropertyName entries -NotePropertyValue $entries
        return $release
    }
    finally {
        $archive.Dispose()
    }
}

Export-ModuleMember -Function Test-ModNexusHomepage, Get-ModReleaseInfo, Get-ModReleasePackage
