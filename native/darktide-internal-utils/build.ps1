param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64",

    [string] $MSBuildPath
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$ProjectFile = Join-Path -Path $ProjectRoot -ChildPath "dtintutils-core.vcxproj"

function Resolve-MSBuildPath {
    param(
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "MSBuild.exe was not found at: $RequestedPath"
        }

        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $ProgramFilesX86 = [System.Environment]::GetFolderPath("ProgramFilesX86")
    $VSWhere = Join-Path -Path $ProgramFilesX86 -ChildPath "Microsoft Visual Studio\Installer\vswhere.exe"

    if (-not (Test-Path -LiteralPath $VSWhere -PathType Leaf)) {
        throw "vswhere.exe was not found at: $VSWhere. Pass -MSBuildPath explicitly."
    }

    $VSWhereArgs = @(
        "-latest"
        "-products"
        "*"
        "-requires"
        "Microsoft.Component.MSBuild"
        "-find"
        "MSBuild\**\Bin\MSBuild.exe"
    )
    $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $VSWhere
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true

    foreach ($Argument in $VSWhereArgs) {
        [void] $StartInfo.ArgumentList.Add($Argument)
    }

    $Process = [System.Diagnostics.Process]::Start($StartInfo)
    $StandardOutput = $Process.StandardOutput.ReadToEnd()
    $StandardError = $Process.StandardError.ReadToEnd()
    $Process.WaitForExit()

    if ($Process.ExitCode -ne 0) {
        throw "vswhere.exe failed with exit code $($Process.ExitCode): $StandardError"
    }

    $Candidates = @(
        $StandardOutput -split "`r?`n" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )

    if ($Candidates.Count -ne 1) {
        throw "Expected exactly one MSBuild.exe from vswhere.exe, found $($Candidates.Count). Pass -MSBuildPath explicitly."
    }

    return (Resolve-Path -LiteralPath $Candidates[0]).Path
}

$MSBuild = Resolve-MSBuildPath -RequestedPath $MSBuildPath

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

$OutputDir = Join-Path -Path $ProjectRoot -ChildPath "bin\$Platform\$Configuration"
$LibraryPath = Join-Path -Path $OutputDir -ChildPath "dtintutils-core.lib"

if (-not (Test-Path -LiteralPath $LibraryPath -PathType Leaf)) {
    throw "Build output was not found: $LibraryPath"
}

Write-Host $LibraryPath
