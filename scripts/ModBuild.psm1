Set-StrictMode -Version Latest

function Invoke-RepositoryGit {
    param([string] $RepositoryRoot, [string[]] $Arguments)

    $output = & git -C $RepositoryRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
    return $output
}

function Get-ModBuildInfo {
    param([string] $RepositoryRoot, [string] $Name, [hashtable] $Information)

    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        throw "Invalid mod directory name: $Name"
    }
    $version = $Information['version']
    if ($version -isnot [string] -or $version -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') {
        throw "Missing or invalid version in $Name/info.json"
    }

    $enabled = $true
    $projects = @()
    if ($Information.ContainsKey('_build')) {
        $build = $Information['_build']
        if ($build -isnot [hashtable] -or $build['native'] -isnot [array]) {
            throw "Expected _build.native to be an array in $Name/info.json"
        }
        if ($build.ContainsKey('enabled')) {
            if ($build['enabled'] -isnot [bool]) {
                throw "Expected _build.enabled to be a boolean in $Name/info.json"
            }
            $enabled = $build['enabled']
        }
        $projects = @($build['native'])
    }

    $result = [pscustomobject]@{
        mod = $Name
        version = $version
        enabled = $enabled
        native = $projects
        go_mod = ''
        needs_msys2 = $false
        needs_meson = $false
        needs_cmake = $false
    }
    if (-not $enabled) {
        return $result
    }

    $goVersion = [version] '0.0'
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($project in $projects) {
        if ($project -isnot [string] -or $project -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$' -or -not $seen.Add($project)) {
            throw "Invalid or duplicate native project in ${Name}: $project"
        }
        $projectRoot = Join-Path $RepositoryRoot "native/$project"
        $script = Join-Path $projectRoot 'build.ps1'
        if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
            throw "Native build script was not found: $script"
        }
        $parameters = (Get-Command -Name $script -ErrorAction Stop).Parameters
        $result.needs_msys2 = $result.needs_msys2 -or $parameters.ContainsKey('Ucrt64Bin')
        $result.needs_meson = $result.needs_meson -or $parameters.ContainsKey('MesonPath')
        $result.needs_cmake = $result.needs_cmake -or $parameters.ContainsKey('CMakePath')
        $moduleFile = Join-Path $projectRoot 'go.mod'
        if (Test-Path -LiteralPath $moduleFile -PathType Leaf) {
            $module = Get-Content -LiteralPath $moduleFile -Raw
            if ($module -notmatch '(?m)^go\s+(\d+\.\d+(?:\.\d+)?)\s*$') {
                throw "Go version was not found in: $moduleFile"
            }
            $requiredVersion = [version] $Matches[1]
            if ($requiredVersion -gt $goVersion) {
                $goVersion = $requiredVersion
                $result.go_mod = "native/$project/go.mod"
            }
        }
    }

    return $result
}

function Copy-PackageFile {
    param([string] $Source, [string] $Destination)

    if (Test-Path -LiteralPath $Destination) {
        throw "Package inputs would overwrite the same file: $Destination"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination
}

Export-ModuleMember -Function Invoke-RepositoryGit, Get-ModBuildInfo, Copy-PackageFile
