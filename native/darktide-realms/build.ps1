param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "darktide-realms.vcxproj"
$MSBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$CMake = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"

if (-not (Test-Path -LiteralPath $MSBuild -PathType Leaf)) {
    throw "MSBuild.exe was not found at: $MSBuild"
}

if (-not (Test-Path -LiteralPath $CMake -PathType Leaf)) {
    throw "CMake.exe was not found at: $CMake"
}

$AudioBuild = Join-Path $ProjectRoot "obj\audio"
& $CMake -S (Join-Path $ProjectRoot "third_party") -B $AudioBuild -G "Visual Studio 17 2022" -A $Platform
if ($LASTEXITCODE -ne 0) {
    throw "Audio dependency configuration failed."
}
& $CMake --build $AudioBuild --config $Configuration --target opus --parallel
if ($LASTEXITCODE -ne 0) {
    throw "Audio dependency build failed."
}

$MesonEnvironment = Join-Path $ProjectRoot "obj\audio-tools"
$Meson = Join-Path $MesonEnvironment "Scripts\meson.exe"
if (-not (Test-Path -LiteralPath $Meson -PathType Leaf)) {
    & python -m venv $MesonEnvironment
    if ($LASTEXITCODE -ne 0) { throw "Meson environment creation failed." }
    & (Join-Path $MesonEnvironment "Scripts\python.exe") -m pip install --disable-pip-version-check "meson==1.9.1"
    if ($LASTEXITCODE -ne 0) { throw "Meson installation failed." }
}

$VsRoot = "C:\Program Files\Microsoft Visual Studio\2022\Community"
& (Join-Path $VsRoot "Common7\Tools\Launch-VsDevShell.ps1") -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
$ProcessingBuild = Join-Path $ProjectRoot "obj\webrtc\$Configuration"
$ProcessingSource = Join-Path $AudioBuild "_deps\webrtc-src"
$BuildType = if ($Configuration -eq "Debug") { "debug" } else { "release" }
$Runtime = if ($Configuration -eq "Debug") { "mtd" } else { "mt" }
$SetupArgs = @("setup", $ProcessingBuild, $ProcessingSource, "--backend", "vs2022", "--buildtype", $BuildType,
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
    "/p:Platform=$Platform"
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

$OutputDir = Join-Path $ProjectRoot "bin\$Platform\$Configuration"
$DllPath = Join-Path $OutputDir "darktide-realms.dll"

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
    throw "Build output was not found: $DllPath"
}

Write-Host $DllPath
