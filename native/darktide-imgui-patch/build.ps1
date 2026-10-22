param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("x64")]
    [string] $Platform = "x64",

    [string] $MSBuildPath,

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
$ProjectFile = Join-Path $ProjectRoot "darktide-imgui-patch.vcxproj"

function Resolve-MSBuildPath {
    param([string] $RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "MSBuild.exe was not found at: $RequestedPath"
        }

        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $ProgramFilesX86 = [System.Environment]::GetFolderPath("ProgramFilesX86")
    $VSWhere = Join-Path $ProgramFilesX86 "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $VSWhere -PathType Leaf)) {
        throw "vswhere.exe was not found at: $VSWhere. Pass -MSBuildPath explicitly."
    }

    $Output = & $VSWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find "MSBuild\**\Bin\MSBuild.exe"
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with exit code $LASTEXITCODE."
    }

    $Candidates = @($Output | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($Candidates.Count -ne 1) {
        throw "Expected exactly one MSBuild.exe from vswhere.exe, found $($Candidates.Count). Pass -MSBuildPath explicitly."
    }

    return (Resolve-Path -LiteralPath $Candidates[0]).Path
}

$MSBuild = Resolve-MSBuildPath -RequestedPath $MSBuildPath
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

$DllPath = Join-Path $OutputDir "darktide-imgui-patch.dll"

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf) -or
    (Get-Item -LiteralPath $DllPath).Length -eq 0) {
    throw "Build output was not found or is empty: $DllPath"
}

& $SignArtifact -Path $DllPath -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
Write-Host $DllPath

$PackageBin = Join-Path $PackageDirectory "bin"
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
Copy-Item -LiteralPath $DllPath -Destination $PackageBin -Force
