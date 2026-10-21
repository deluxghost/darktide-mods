param(
    [string] $Version = "dev",

    [string] $OutputDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "release")
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch "^[0-9A-Za-z][0-9A-Za-z._+-]*$") {
    throw "Version contains unsupported characters: $Version"
}

$ProjectRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$OutputDirectoryPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path -Path $ProjectRoot -ChildPath $OutputDirectory))
}
$ProjectPrefix = $ProjectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
    [System.IO.Path]::DirectorySeparatorChar

if (-not $OutputDirectoryPath.StartsWith($ProjectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be inside the project root: $OutputDirectoryPath"
}

$ArchiveName = "darktide-internal-utils.zip"
$ArchivePath = Join-Path -Path $OutputDirectoryPath -ChildPath $ArchiveName
$ChecksumPath = Join-Path -Path $OutputDirectoryPath -ChildPath "SHA256SUMS.txt"
$StagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (
    "darktide-internal-utils-" + [System.Guid]::NewGuid().ToString("N")
)
$TempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$ResolvedStagingRoot = [System.IO.Path]::GetFullPath($StagingRoot)

if (-not $ResolvedStagingRoot.StartsWith($TempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Staging directory is outside the temporary directory: $ResolvedStagingRoot"
}

$PackageFiles = @(
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "include\dtintutils.h"
        Destination = "include\dtintutils.h"
    }
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "bin\x64\Release\dtintutils-core.lib"
        Destination = "lib\msvc\x64\dtintutils-core.lib"
    }
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "bin\ucrt64\Release\libdtintutils-core.a"
        Destination = "lib\ucrt64\x64\libdtintutils-core.a"
    }
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "third_party\minhook\LICENSE.txt"
        Destination = "licenses\MinHook-LICENSE.txt"
    }
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "third_party\zydis\LICENSE"
        Destination = "licenses\Zydis-LICENSE.txt"
    }
    [pscustomobject]@{
        Source = Join-Path -Path $ProjectRoot -ChildPath "third_party\zydis\dependencies\zycore\LICENSE"
        Destination = "licenses\Zycore-LICENSE.txt"
    }
)

foreach ($PackageFile in $PackageFiles) {
    if (-not (Test-Path -LiteralPath $PackageFile.Source -PathType Leaf)) {
        throw "Package input was not found: $($PackageFile.Source)"
    }
}

$NewOutputParams = @{
    ItemType = "Directory"
    Path = $OutputDirectoryPath
    Force = $true
}
New-Item @NewOutputParams | Out-Null

try {
    $NewStagingParams = @{
        ItemType = "Directory"
        Path = $ResolvedStagingRoot
    }
    New-Item @NewStagingParams | Out-Null

    foreach ($PackageFile in $PackageFiles) {
        $DestinationPath = Join-Path -Path $ResolvedStagingRoot -ChildPath $PackageFile.Destination
        $DestinationDirectory = Split-Path -Parent $DestinationPath
        $NewDirectoryParams = @{
            ItemType = "Directory"
            Path = $DestinationDirectory
            Force = $true
        }
        New-Item @NewDirectoryParams | Out-Null

        $CopyParams = @{
            LiteralPath = $PackageFile.Source
            Destination = $DestinationPath
        }
        Copy-Item @CopyParams
    }

    $VersionPath = Join-Path -Path $ResolvedStagingRoot -ChildPath "VERSION"
    Set-Content -LiteralPath $VersionPath -Value $Version -Encoding utf8 -NoNewline

    $ArchiveItems = @(Get-ChildItem -LiteralPath $ResolvedStagingRoot | Select-Object -ExpandProperty FullName)
    if ($ArchiveItems.Count -eq 0) {
        throw "Package staging directory is empty: $ResolvedStagingRoot"
    }

    $CompressParams = @{
        LiteralPath = $ArchiveItems
        DestinationPath = $ArchivePath
        CompressionLevel = "Optimal"
        Force = $true
    }
    Compress-Archive @CompressParams
} finally {
    if (Test-Path -LiteralPath $ResolvedStagingRoot -PathType Container) {
        Remove-Item -LiteralPath $ResolvedStagingRoot -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf) -or
    (Get-Item -LiteralPath $ArchivePath).Length -eq 0) {
    throw "Package output was not found or is empty: $ArchivePath"
}

$ArchiveHash = Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256
$Checksum = "$($ArchiveHash.Hash.ToLowerInvariant())  $ArchiveName"
Set-Content -LiteralPath $ChecksumPath -Value $Checksum -Encoding utf8

Write-Host $ArchivePath
Write-Host $ChecksumPath
