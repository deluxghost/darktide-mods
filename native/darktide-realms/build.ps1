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

    [string] $DtIntUtilsRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "darktide-internal-utils")
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
