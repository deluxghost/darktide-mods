param(
    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"
$DtIntUtilsRoot = Join-Path (Split-Path -Parent $ProjectRoot) "darktide-internal-utils"
$DtIntUtilsBuild = Join-Path $DtIntUtilsRoot "build-ucrt64.ps1"
$DtIntUtilsLibrary = Join-Path $DtIntUtilsRoot "bin\ucrt64\Release\libdtintutils-core.a"
$NativeSourceRoot = Join-Path $ProjectRoot "internal\resource\native"
$Windres = Join-Path $Ucrt64Bin "windres.exe"
$Clang = Join-Path $Ucrt64Bin "clang.exe"

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
$NativeSourceBytes = [System.Text.Encoding]::UTF8.GetBytes($NativeSourceManifest -join "`n")
$NativeSourceHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($NativeSourceBytes)
)

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Clang
$env:CGO_ENABLED = "1"
$env:CGO_CPPFLAGS = "-DDTINTUTILS_BUILD_ID_$DtIntUtilsHash=1 -DSIMPLE_ASSETS_NATIVE_BUILD_ID_$NativeSourceHash=1"

& $Windres "$ProjectRoot\runtime\versioninfo.rc" -O coff -o "$ProjectRoot\runtime\versioninfo.syso"
& go build -buildvcs=false -buildmode=c-shared -ldflags '-s -w -extldflags "-static"' -o "$BuildDir\simple-assets-runtime.dll" "$ProjectRoot\runtime"
