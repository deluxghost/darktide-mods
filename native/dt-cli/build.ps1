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

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Clang
$env:CGO_CFLAGS = "-DDTINTUTILS_BUILD_ID_$DtIntUtilsHash=1"

Push-Location -LiteralPath $ProjectRoot
try {
    & go test ./...
    & go build -buildvcs=false -trimpath -o "$BuildDir\dt-cli.exe" "$ProjectRoot\cmd\dt-cli"

    $env:CGO_ENABLED = "1"
    & $Windres "$ProjectRoot\runtime\versioninfo.rc" -O coff -o "$ProjectRoot\runtime\versioninfo.syso"
    & go build -buildvcs=false -buildmode=c-shared -ldflags '-s -w -extldflags "-static"' -o "$BuildDir\luaexec-runtime.dll" "$ProjectRoot\runtime"
}
finally {
    Pop-Location
}
