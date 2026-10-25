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
$MinHookInclude = Join-Path $DtIntUtilsRoot "third_party\minhook\include"
$MinHookSource = Join-Path $DtIntUtilsRoot "third_party\minhook\src"
$MinHookPatch = Join-Path $ProjectRoot "minhook-absolute.patch"
$DtIntUtilsLibraryDirectory = Join-Path $DtIntUtilsRoot "bin\ucrt64\Release"
$DtIntUtilsLibrary = Join-Path $DtIntUtilsLibraryDirectory "libdtintutils-core.a"
$NativeSourceRoot = Join-Path $ProjectRoot "internal\resource\native"
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

# Apply only the SA backend changes to a build-local copy of the existing dependency.
$MinHookBuild = Join-Path $BuildDir "minhook"
New-Item -ItemType Directory -Force -Path $MinHookBuild | Out-Null
foreach ($Name in @("buffer.c", "buffer.h", "hook.c", "trampoline.c", "trampoline.h")) {
    Copy-Item -LiteralPath (Join-Path $MinHookSource $Name) -Destination $MinHookBuild -Force
}
& git -C $ProjectRoot apply --directory build/minhook $MinHookPatch
$DtIntUtilsHash = (Get-FileHash -LiteralPath $DtIntUtilsLibrary -Algorithm SHA256).Hash
$NativeSourceFiles = @(
    Get-ChildItem -LiteralPath $NativeSourceRoot -Recurse -File |
        Where-Object { $_.Extension -in ".c", ".h" } |
        Sort-Object FullName
)
if ($NativeSourceFiles.Count -eq 0) {
    throw "SimpleAssets native source files were not found under: $NativeSourceRoot"
}
$NativeSourceManifest = $NativeSourceFiles | ForEach-Object {
    $RelativePath = [System.IO.Path]::GetRelativePath($NativeSourceRoot, $_.FullName).Replace("\", "/")
    $Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    "$RelativePath=$Hash"
}
$NativeSourceManifest += "minhook-absolute.patch=$((Get-FileHash -LiteralPath $MinHookPatch -Algorithm SHA256).Hash)"
$NativeSourceBytes = [System.Text.Encoding]::UTF8.GetBytes($NativeSourceManifest -join "`n")
$NativeSourceHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($NativeSourceBytes)
)

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Clang
$env:CGO_ENABLED = "1"
$env:CGO_CPPFLAGS = "`"-I$DtIntUtilsInclude`" `"-I$BuildDir`" `"-I$MinHookInclude`" `"-I$MinHookSource`" -DDTINTUTILS_BUILD_ID_$DtIntUtilsHash=1 -DSIMPLE_ASSETS_NATIVE_BUILD_ID_$NativeSourceHash=1"
$env:CGO_LDFLAGS = "`"-L$DtIntUtilsLibraryDirectory`" -ldtintutils-core"

$RuntimePath = Join-Path $BuildDir "simple-assets-runtime.dll"
$RuntimeHeaderPath = Join-Path $BuildDir "simple-assets-runtime.h"

Push-Location -LiteralPath $ProjectRoot
try {
    & $Windres "$ProjectRoot\runtime\versioninfo.rc" -O coff -o "$ProjectRoot\runtime\versioninfo.syso"
    & $Go build -buildvcs=false -trimpath -buildmode=c-shared -ldflags '-s -w -extldflags "-static"' -o $RuntimePath "$ProjectRoot\runtime"
    & $SignArtifact -Path $RuntimePath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
}
finally {
    Pop-Location
}

foreach ($OutputPath in @($RuntimePath, $RuntimeHeaderPath)) {
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or
        (Get-Item -LiteralPath $OutputPath).Length -eq 0) {
        throw "Build output was not found or is empty: $OutputPath"
    }

    Write-Host $OutputPath
}

$PackageBin = Join-Path $PackageDirectory "bin"
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
foreach ($OutputPath in @($RuntimePath)) {
    Copy-Item -LiteralPath $OutputPath -Destination $PackageBin -Force
}
