param(
    [ValidateSet("Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64",

    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin",

    [string] $OutputDirectory,

    [string] $SigningConfig,

    [ValidateSet('Local', 'AzureCli')]
    [string] $SigningAuthentication = 'Local'
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
$Windres = Join-Path $Ucrt64Bin "windres.exe"
$Gcc = Join-Path $Ucrt64Bin "gcc.exe"
$Go = (Get-Command go -CommandType Application -TotalCount 1 -ErrorAction Stop).Source

if (-not (Test-Path -LiteralPath $Windres -PathType Leaf)) {
    throw "windres.exe was not found at: $Windres"
}

if (-not (Test-Path -LiteralPath $Gcc -PathType Leaf)) {
    throw "gcc.exe was not found at: $Gcc"
}

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$env:PATH = "$Ucrt64Bin;$env:PATH"
$env:CC = $Gcc

$HandlerPath = Join-Path $BuildDir "darktide-link-handler.exe"
$BridgePath = Join-Path $BuildDir "darktide-link-bridge.dll"
$BridgeHeaderPath = Join-Path $BuildDir "darktide-link-bridge.h"

Push-Location -LiteralPath $ProjectRoot
try {
    & $Windres "$ProjectRoot\cmd\handler\versioninfo.rc" -O coff -o "$ProjectRoot\cmd\handler\versioninfo.syso"
    & $Windres "$ProjectRoot\bridge\versioninfo.rc" -O coff -o "$ProjectRoot\bridge\versioninfo.syso"

    & $Go build -buildvcs=false -trimpath -ldflags "-H=windowsgui" -o $HandlerPath "$ProjectRoot\cmd\handler"
    & $SignArtifact -Path $HandlerPath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication

    $env:CGO_ENABLED = "1"
    & $Go build -buildvcs=false -trimpath -buildmode=c-shared -ldflags '-extldflags "-static"' -o $BridgePath "$ProjectRoot\bridge"
    & $SignArtifact -Path $BridgePath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
}
finally {
    Pop-Location
}

foreach ($OutputPath in @($HandlerPath, $BridgePath, $BridgeHeaderPath)) {
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or
        (Get-Item -LiteralPath $OutputPath).Length -eq 0) {
        throw "Build output was not found or is empty: $OutputPath"
    }

    Write-Host $OutputPath
}

$PackageBin = Join-Path $PackageDirectory "bin"
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
foreach ($OutputPath in @($HandlerPath, $BridgePath)) {
    Copy-Item -LiteralPath $OutputPath -Destination $PackageBin -Force
}
