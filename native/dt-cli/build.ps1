param(
    [ValidateSet("Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64",

    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin",

    [string] $OutputDirectory,

    [string] $SigningConfig,

    [ValidateSet('Local', 'AzureCli')]
    [string] $SigningAuthentication = 'Local',

    [string] $DtIntUtilsRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "darktide-internal-utils")
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$SignArtifact = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sign-Artifact.ps1'
$PackageDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $ProjectRoot "build/package"
} elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $OutputDirectory))
}
$BuildDir = Join-Path $ProjectRoot "build"
$DtIntUtilsRoot = if ([System.IO.Path]::IsPathRooted($DtIntUtilsRoot)) {
    [System.IO.Path]::GetFullPath($DtIntUtilsRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $DtIntUtilsRoot))
}
$DtIntUtilsBuild = Join-Path $DtIntUtilsRoot "build-ucrt64.ps1"
$DtIntUtilsInclude = Join-Path $DtIntUtilsRoot "include"
$DtIntUtilsLibraryDirectory = Join-Path $DtIntUtilsRoot "bin\ucrt64\Release"
$DtIntUtilsLibrary = Join-Path $DtIntUtilsRoot "bin\ucrt64\Release\libdtintutils-core.a"
$Windres = Join-Path $Ucrt64Bin "windres.exe"
$Clang = Join-Path $Ucrt64Bin "clang.exe"
$Go = (Get-Command go -CommandType Application -TotalCount 1 -ErrorAction Stop).Source

if (-not (Test-Path -LiteralPath $Windres -PathType Leaf)) {
    throw "windres.exe was not found at: $Windres"
}

if (-not (Test-Path -LiteralPath $Clang -PathType Leaf)) {
    throw "clang.exe was not found at: $Clang"
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

if (-not (Test-Path -LiteralPath $DtIntUtilsBuild -PathType Leaf)) {
    throw "Darktide Internal Utils UCRT64 build script was not found at: $DtIntUtilsBuild"
}

& $DtIntUtilsBuild -Configuration Release -Ucrt64Bin $Ucrt64Bin

if (-not (Test-Path -LiteralPath $DtIntUtilsLibrary -PathType Leaf)) {
    throw "Darktide Internal Utils UCRT64 library was not found at: $DtIntUtilsLibrary"
}

$DtIntUtilsHash = (Get-FileHash -LiteralPath $DtIntUtilsLibrary -Algorithm SHA256).Hash

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Clang
$env:CGO_ENABLED = "1"
$env:CGO_CFLAGS = "`"-I$DtIntUtilsInclude`" -DDTINTUTILS_BUILD_ID_$DtIntUtilsHash=1"
$env:CGO_LDFLAGS = "`"-L$DtIntUtilsLibraryDirectory`" -ldtintutils-core"

$CliPath = Join-Path $BuildDir "dt-cli.exe"
$RuntimePath = Join-Path $BuildDir "luaexec-runtime.dll"
$RuntimeHeaderPath = Join-Path $BuildDir "luaexec-runtime.h"

Push-Location -LiteralPath $ProjectRoot
try {
    & $Go build -buildvcs=false -trimpath -o $CliPath "$ProjectRoot\cmd\dt-cli"
    & $SignArtifact -Path $CliPath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication

    & $Windres "$ProjectRoot\runtime\versioninfo.rc" -O coff -o "$ProjectRoot\runtime\versioninfo.syso"
    & $Go build -buildvcs=false -trimpath -buildmode=c-shared -ldflags '-s -w -extldflags "-static"' -o $RuntimePath "$ProjectRoot\runtime"
    & $SignArtifact -Path $RuntimePath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
}
finally {
    Pop-Location
}

foreach ($OutputPath in @($CliPath, $RuntimePath, $RuntimeHeaderPath)) {
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or
        (Get-Item -LiteralPath $OutputPath).Length -eq 0) {
        throw "Build output was not found or is empty: $OutputPath"
    }

    Write-Host $OutputPath
}

$PackageBin = Join-Path $PackageDirectory "bin"
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
foreach ($OutputPath in @($CliPath, $RuntimePath)) {
    Copy-Item -LiteralPath $OutputPath -Destination $PackageBin -Force
}
