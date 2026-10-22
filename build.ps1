param(
    [Parameter(Mandatory)]
    [string[]] $Mod,
    [string] $OutputDirectory = (Join-Path $PSScriptRoot 'output'),
    [string] $SigningConfig,
    [ValidateSet('Local', 'AzureCli')]
    [string] $SigningAuthentication = 'Local',
    [string] $Ucrt64Bin = 'C:\msys64\ucrt64\bin',
    [string] $MSBuildPath,
    [string] $CMakePath,
    [string] $VisualStudioRoot,
    [string] $VsDevShellPath,
    [string] $MesonPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Import-Module (Join-Path $PSScriptRoot 'scripts/ModBuild.psm1') -Force
$RepositoryRoot = $PSScriptRoot
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory, $RepositoryRoot)
$PowerShell = Join-Path $PSHOME 'pwsh.exe'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($name in $Mod) {
    $informationPath = Join-Path $RepositoryRoot "$name/info.json"
    $information = Get-Content -LiteralPath $informationPath -Raw | ConvertFrom-Json -AsHashtable
    $build = Get-ModBuildInfo -RepositoryRoot $RepositoryRoot -Name $name -Information $information
    if (-not $build.enabled) {
        throw "Build is disabled in $name/info.json"
    }
    $modRoot = Join-Path $RepositoryRoot $name
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot "$name.mod") -PathType Leaf)) {
        throw "Mod entrypoint was not found: $name"
    }

    $workingDirectory = Join-Path $OutputDirectory ([guid]::NewGuid().ToString('N'))
    $runtimeRoot = Join-Path $workingDirectory 'runtime'
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null

    foreach ($project in $build.native) {
        $script = Join-Path $RepositoryRoot "native/$project/build.ps1"
        $nativeOutput = Join-Path $workingDirectory $project
        $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $script,
            '-Configuration', 'Release', '-Platform', 'x64', '-OutputDirectory', $nativeOutput)
        $parameters = (Get-Command -Name $script -ErrorAction Stop).Parameters
        foreach ($parameter in @('Ucrt64Bin', 'MSBuildPath', 'CMakePath', 'VisualStudioRoot', 'VsDevShellPath', 'MesonPath', 'SigningConfig', 'SigningAuthentication')) {
            $value = Get-Variable -Name $parameter -ValueOnly
            if ($parameters.ContainsKey($parameter) -and -not [string]::IsNullOrWhiteSpace($value)) {
                $arguments += @("-$parameter", $value)
            }
        }
        & $PowerShell @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Native build failed for ${project}: exit code $LASTEXITCODE"
        }
        $nativeFiles = @(Get-ChildItem -LiteralPath $nativeOutput -Recurse -File)
        if ($nativeFiles.Count -eq 0) {
            throw "Native build produced no distributable files: $project"
        }
        foreach ($file in $nativeFiles) {
            $relative = [System.IO.Path]::GetRelativePath($nativeOutput, $file.FullName)
            Copy-PackageFile $file.FullName (Join-Path $runtimeRoot $relative)
        }
    }

    foreach ($file in Get-ChildItem -LiteralPath $runtimeRoot -Recurse -File) {
        $relative = [System.IO.Path]::GetRelativePath($runtimeRoot, $file.FullName)
        $destination = Join-Path $modRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }

    $zipName = "$name.zip"
    $temporaryZip = Join-Path $workingDirectory $zipName
    [System.IO.Compression.ZipFile]::CreateFromDirectory($modRoot, $temporaryZip,
        [System.IO.Compression.CompressionLevel]::SmallestSize, $true, [System.Text.UTF8Encoding]::new($false))
    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryZip)
    try {
        foreach ($requiredFile in @("$name/$name.mod", "$name/info.json")) {
            if ($null -eq $archive.GetEntry($requiredFile)) {
                throw "ZIP is missing its required entry: $requiredFile"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
    $zipPath = Join-Path $OutputDirectory $zipName
    Move-Item -LiteralPath $temporaryZip -Destination $zipPath -Force
    if (-not $workingDirectory.StartsWith($OutputDirectory.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Temporary build directory escaped the output directory: $workingDirectory"
    }
    Remove-Item -LiteralPath $workingDirectory -Recurse -Force
    Write-Host $zipPath
}
