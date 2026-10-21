param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "darktide-imgui-patch.vcxproj"
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
    $StartInfo.ArgumentList.Add($Argument)
}

$StartInfo.Environment.Clear()
$SeenEnvironmentKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$PathValue = [System.Environment]::GetEnvironmentVariable("Path", "Process")

foreach ($Entry in [System.Environment]::GetEnvironmentVariables("Process").GetEnumerator()) {
    $Name = [string] $Entry.Key
    if ($Name -ieq "Path") {
        continue
    }
    if ($SeenEnvironmentKeys.Add($Name)) {
        $StartInfo.Environment[$Name] = [string] $Entry.Value
    }
}

$StartInfo.Environment["Path"] = $PathValue

$Process = [System.Diagnostics.Process]::Start($StartInfo)
$Process.WaitForExit()

if ($Process.ExitCode -ne 0) {
    throw "MSBuild failed with exit code $($Process.ExitCode)."
}

$OutputDir = Join-Path $ProjectRoot "bin\$Platform\$Configuration"
$DllPath = Join-Path $OutputDir "darktide-imgui-patch.dll"

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
    throw "Build output was not found: $DllPath"
}

Write-Host $DllPath
