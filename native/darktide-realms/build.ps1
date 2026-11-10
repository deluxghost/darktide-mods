param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64",

    [string] $VisualStudioRoot,

    [string] $MSBuildPath,

    [string] $CMakePath,

    [string] $VsDevShellPath,

    [string] $MesonPath,

    [string] $OutputDirectory,

    [string] $SigningConfig,

    [ValidateSet('Local', 'AzureCli')]
    [string] $SigningAuthentication = 'Local',

    [string] $DtIntUtilsRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "darktide-internal-utils"),

    # Extracted EOS SDK (the folder containing SDK\Include and SDK\Bin). When present, the build
    # verifies src\eos\eos_api.h against the official headers and packages the SDK runtime DLL.
    [string] $EosSdkRoot = $env:REALMS_EOS_SDK_ROOT,

    # JSON file with productId, sandboxId, deploymentId, clientId and clientSecret. REALMS_EOS_*
    # environment variables take precedence. Without either, the runtime is built without EOS.
    [string] $EosConfig = (Join-Path $PSScriptRoot "eos.local.json")
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$SignArtifact = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sign-Artifact.ps1'
$ProjectFile = Join-Path $ProjectRoot "darktide-realms.vcxproj"

function Resolve-VisualStudioRoot {
    param([string] $RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Container)) {
            throw "Visual Studio was not found at: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $ProgramFilesX86 = [System.Environment]::GetFolderPath("ProgramFilesX86")
    $VSWhere = Join-Path $ProgramFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $VSWhere -PathType Leaf)) {
        throw "vswhere.exe was not found at: $VSWhere. Pass -VisualStudioRoot or all Visual Studio tool paths explicitly."
    }

    $Output = & $VSWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with exit code $LASTEXITCODE."
    }

    $Candidates = @($Output | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
    if ($Candidates.Count -ne 1) {
        throw "Expected exactly one Visual Studio installation from vswhere.exe, found $($Candidates.Count)."
    }

    return (Resolve-Path -LiteralPath $Candidates[0]).Path
}

function Resolve-RequiredFile {
    param(
        [string] $RequestedPath,
        [string] $DefaultPath,
        [string] $DisplayName
    )

    $Path = if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $DefaultPath } else { $RequestedPath }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$DisplayName was not found at: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

$NeedsVisualStudioRoot = [string]::IsNullOrWhiteSpace($MSBuildPath) -or
    [string]::IsNullOrWhiteSpace($CMakePath) -or
    [string]::IsNullOrWhiteSpace($VsDevShellPath)
$ResolvedVisualStudioRoot = if ($NeedsVisualStudioRoot) {
    Resolve-VisualStudioRoot -RequestedPath $VisualStudioRoot
} else {
    $null
}
$DefaultMSBuildPath = if ([string]::IsNullOrWhiteSpace($MSBuildPath)) {
    Join-Path $ResolvedVisualStudioRoot "MSBuild\Current\Bin\MSBuild.exe"
}
$DefaultCMakePath = if ([string]::IsNullOrWhiteSpace($CMakePath)) {
    Join-Path $ResolvedVisualStudioRoot "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
}
$DefaultVsDevShellPath = if ([string]::IsNullOrWhiteSpace($VsDevShellPath)) {
    Join-Path $ResolvedVisualStudioRoot "Common7\Tools\Launch-VsDevShell.ps1"
}
$MSBuild = Resolve-RequiredFile -RequestedPath $MSBuildPath `
    -DefaultPath $DefaultMSBuildPath `
    -DisplayName "MSBuild.exe"
$CMake = Resolve-RequiredFile -RequestedPath $CMakePath `
    -DefaultPath $DefaultCMakePath `
    -DisplayName "CMake.exe"
$VsDevShell = Resolve-RequiredFile -RequestedPath $VsDevShellPath `
    -DefaultPath $DefaultVsDevShellPath `
    -DisplayName "Launch-VsDevShell.ps1"
$PackageDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $ProjectRoot "bin/$Platform/$Configuration/package"
} elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $OutputDirectory))
}
$OutputDir = Join-Path $ProjectRoot "bin/$Platform/$Configuration"
$DtIntUtilsRoot = if ([System.IO.Path]::IsPathRooted($DtIntUtilsRoot)) {
    [System.IO.Path]::GetFullPath($DtIntUtilsRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $DtIntUtilsRoot))
}
$DtIntUtilsProject = Join-Path $DtIntUtilsRoot "dtintutils-core.vcxproj"
if (-not (Test-Path -LiteralPath $DtIntUtilsProject -PathType Leaf)) {
    throw "Darktide Internal Utils project was not found at: $DtIntUtilsProject"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$EosSdkInclude = $null
$EosSdkLibrary = $null
if (-not [string]::IsNullOrWhiteSpace($EosSdkRoot)) {
    $EosSdkInclude = Join-Path $EosSdkRoot "SDK\Include"
    $EosSdkLibrary = Join-Path $EosSdkRoot "SDK\Bin\EOSSDK-Win64-Shipping.dll"
    if (-not (Test-Path -LiteralPath (Join-Path $EosSdkInclude "eos_sdk.h") -PathType Leaf) -or
        -not (Test-Path -LiteralPath $EosSdkLibrary -PathType Leaf)) {
        throw "EOS SDK was not found at: $EosSdkRoot"
    }
    $EosSdkInclude = (Resolve-Path -LiteralPath $EosSdkInclude).Path
}

function ConvertTo-CString {
    param([string] $Value)
    return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

# Credentials are compiled into the runtime from a generated header that never enters the repository.
$EosFields = [ordered]@{
    PRODUCT_ID = "productId"
    SANDBOX_ID = "sandboxId"
    DEPLOYMENT_ID = "deploymentId"
    CLIENT_ID = "clientId"
    CLIENT_SECRET = "clientSecret"
}
$EosValues = [ordered]@{}
$EosFile = if (Test-Path -LiteralPath $EosConfig -PathType Leaf) {
    Get-Content -LiteralPath $EosConfig -Raw | ConvertFrom-Json -AsHashtable
} else {
    @{}
}
foreach ($Field in $EosFields.GetEnumerator()) {
    $Value = [System.Environment]::GetEnvironmentVariable("REALMS_EOS_$($Field.Key)")
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = [string] $EosFile[$Field.Value] }
    $EosValues[$Field.Key] = $Value.Trim()
}
$EosConfigured = @($EosValues.Values | Where-Object { $_ -ne "" }).Count
if ($EosConfigured -ne 0 -and $EosConfigured -ne $EosValues.Count) {
    throw "EOS configuration is incomplete. Provide all of: $($EosFields.Values -join ', ')."
}
$GeneratedDirectory = Join-Path $ProjectRoot "obj\generated"
New-Item -ItemType Directory -Force -Path $GeneratedDirectory | Out-Null
$EosHeader = @("#pragma once", "// Generated by build.ps1. Do not commit.")
if ($EosConfigured -ne 0) {
    foreach ($Entry in $EosValues.GetEnumerator()) {
        $EosHeader += "#define REALMS_EOS_$($Entry.Key) $(ConvertTo-CString $Entry.Value)"
    }
    if ($null -eq $EosSdkLibrary) {
        Write-Warning "EOS is configured but -EosSdkRoot is not set, so the package will not contain the EOS SDK DLL."
    }
} else {
    Write-Host "EOS is not configured. Building without cross-platform play."
}
$EosHeaderPath = Join-Path $GeneratedDirectory "realms_eos_config.h"
$EosHeaderText = ($EosHeader -join "`n") + "`n"
# Rewriting identical content would force a rebuild of the EOS translation unit every time.
if (-not (Test-Path -LiteralPath $EosHeaderPath) -or (Get-Content -LiteralPath $EosHeaderPath -Raw) -ne $EosHeaderText) {
    Set-Content -LiteralPath $EosHeaderPath -Value $EosHeaderText -NoNewline -Encoding utf8NoBOM
}

$AudioBuild = Join-Path $ProjectRoot "obj\audio"
$VisualStudioMajorVersion = ([version] (& $MSBuild -version -nologo)).Major
$CMakeCapabilities = & $CMake -E capabilities | ConvertFrom-Json
$CMakeGenerators = @($CMakeCapabilities.generators | Where-Object { $_.name -like "Visual Studio $VisualStudioMajorVersion *" })
if ($CMakeGenerators.Count -ne 1) {
    throw "Expected exactly one CMake generator for Visual Studio $VisualStudioMajorVersion, found $($CMakeGenerators.Count)."
}
& $CMake -S (Join-Path $ProjectRoot "third_party") -B $AudioBuild -G $CMakeGenerators[0].name -A $Platform
if ($LASTEXITCODE -ne 0) {
    throw "Audio dependency configuration failed."
}
& $CMake --build $AudioBuild --config $Configuration --target opus --parallel
if ($LASTEXITCODE -ne 0) {
    throw "Audio dependency build failed."
}

$MesonCommand = if ([string]::IsNullOrWhiteSpace($MesonPath)) { "meson" } else { $MesonPath }
$Meson = (Get-Command $MesonCommand -CommandType Application -ErrorAction Stop).Source

# The developer shell's cmd encoding conversion can corrupt Unicode module paths.
$PowerShellModulePath = $env:PSModulePath
& $VsDevShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
$env:PSModulePath = $PowerShellModulePath
$ProcessingBuild = Join-Path $ProjectRoot "obj\webrtc\$Configuration"
$ProcessingSource = Join-Path $AudioBuild "_deps\webrtc-src"
$BuildType = if ($Configuration -eq "Debug") { "debug" } else { "release" }
$Runtime = if ($Configuration -eq "Debug") { "mtd" } else { "mt" }
$SetupArgs = @("setup", $ProcessingBuild, $ProcessingSource, "--backend", "ninja", "--buildtype", $BuildType,
    "--default-library", "static", "-Db_vscrt=$Runtime", "-Dcpp_std=c++20", "--force-fallback-for=absl_base")
if (Test-Path -LiteralPath (Join-Path $ProcessingBuild "meson-private\coredata.dat")) {
    $SetupArgs += "--reconfigure"
}
& $Meson @SetupArgs
if ($LASTEXITCODE -ne 0) { throw "Audio processing configuration failed." }
& $Meson compile -C $ProcessingBuild "webrtc-audio-processing-2"
if ($LASTEXITCODE -ne 0) { throw "Audio processing build failed." }

$ProcessingLib = Join-Path $ProcessingBuild "webrtc.lib"
$UpstreamLib = Join-Path $ProcessingBuild "webrtc\modules\audio_processing\libwebrtc-audio-processing-2.a"
Copy-Item -LiteralPath $UpstreamLib -Destination $ProcessingLib

$MSBuildArgs = @(
    $ProjectFile,
    "/m",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/p:DtIntUtilsRoot=$DtIntUtilsRoot"
)
if ($null -ne $EosSdkInclude) {
    $MSBuildArgs += "/p:EosSdkInclude=$EosSdkInclude"
}

$StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
$StartInfo.FileName = $MSBuild
$StartInfo.WorkingDirectory = $ProjectRoot
$StartInfo.UseShellExecute = $false

foreach ($Argument in $MSBuildArgs) {
    [void] $StartInfo.ArgumentList.Add($Argument)
}

$Process = [System.Diagnostics.Process]::Start($StartInfo)
$Process.WaitForExit()

if ($Process.ExitCode -ne 0) {
    throw "MSBuild failed with exit code $($Process.ExitCode)."
}

$DllPath = Join-Path $OutputDir "darktide-realms.dll"

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf) -or
    (Get-Item -LiteralPath $DllPath).Length -eq 0) {
    throw "Build output was not found or is empty: $DllPath"
}

& $SignArtifact -Path $DllPath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
Write-Host $DllPath

$PackageBin = Join-Path $PackageDirectory "bin"
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
Copy-Item -LiteralPath $DllPath -Destination $PackageBin -Force
$PackagedEosLibrary = Join-Path $PackageBin "EOSSDK-Win64-Shipping.dll"
if ($EosConfigured -ne 0 -and $null -ne $EosSdkLibrary) {
    # Epic signs the SDK runtime, so it is redistributed unmodified next to the Realms runtime.
    Copy-Item -LiteralPath $EosSdkLibrary -Destination $PackagedEosLibrary -Force
} elseif (Test-Path -LiteralPath $PackagedEosLibrary) {
    Remove-Item -LiteralPath $PackagedEosLibrary -Force
}
