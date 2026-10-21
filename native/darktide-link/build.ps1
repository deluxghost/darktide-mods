param(
    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"
$Windres = Join-Path $Ucrt64Bin "windres.exe"
$Gcc = Join-Path $Ucrt64Bin "gcc.exe"

if (-not (Test-Path -LiteralPath $Windres -PathType Leaf)) {
    throw "windres.exe was not found at: $Windres"
}

if (-not (Test-Path -LiteralPath $Gcc -PathType Leaf)) {
    throw "gcc.exe was not found at: $Gcc"
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Gcc

& $Windres "$ProjectRoot\cmd\handler\versioninfo.rc" -O coff -o "$ProjectRoot\cmd\handler\versioninfo.syso"
& $Windres "$ProjectRoot\bridge\versioninfo.rc" -O coff -o "$ProjectRoot\bridge\versioninfo.syso"

& go build -ldflags "-H=windowsgui" -o "$BuildDir\darktide-link-handler.exe" "$ProjectRoot\cmd\handler"

$env:CGO_ENABLED = "1"
& go build -buildmode=c-shared -ldflags '-extldflags "-static"' -o "$BuildDir\darktide-link-bridge.dll" "$ProjectRoot\bridge"
