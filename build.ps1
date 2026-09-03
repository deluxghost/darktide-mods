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

if (-not (Test-Path -LiteralPath $MSBuild -PathType Leaf)) {
    throw "MSBuild.exe was not found at: $MSBuild"
}

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
