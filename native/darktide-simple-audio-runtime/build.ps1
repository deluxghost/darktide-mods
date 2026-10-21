param(
    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"
$Windres = Join-Path $Ucrt64Bin "windres.exe"
$Gcc = Join-Path $Ucrt64Bin "gcc.exe"
$Gxx = Join-Path $Ucrt64Bin "g++.exe"

if (-not (Test-Path -LiteralPath $Windres -PathType Leaf)) {
    throw "windres.exe was not found at: $Windres"
}

if (-not (Test-Path -LiteralPath $Gcc -PathType Leaf)) {
    throw "gcc.exe was not found at: $Gcc"
}

if (-not (Test-Path -LiteralPath $Gxx -PathType Leaf)) {
    throw "g++.exe was not found at: $Gxx"
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Gcc
$env:CXX = $Gxx
$env:CGO_ENABLED = "1"

& $Windres "$ProjectRoot\runtime\versioninfo.rc" -O coff -o "$ProjectRoot\runtime\versioninfo.syso"
& go build -buildvcs=false -buildmode=c-shared -ldflags '-s -w -extldflags "-static"' -o "$BuildDir\simple-audio-runtime.dll" "$ProjectRoot\runtime"
