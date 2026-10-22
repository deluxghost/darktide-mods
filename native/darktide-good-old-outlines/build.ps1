param(
    [ValidateSet('Release')][string] $Configuration = 'Release',
    [ValidateSet('x64')][string] $Platform = 'x64',
    [string] $SdkVersion = '10.0.26100.0',
    [string] $MSBuildPath,
    [string] $OutputDirectory,
    [string] $SigningConfig,
    [ValidateSet('Local', 'AzureCli')][string] $SigningAuthentication = 'Local',
    [string] $DtIntUtilsRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'darktide-internal-utils')
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$SignArtifact = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sign-Artifact.ps1'

function Resolve-MSBuildPath {
    param([string] $RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "MSBuild.exe was not found at: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $programFilesX86 = [System.Environment]::GetFolderPath('ProgramFilesX86')
    $vswhere = Join-Path $programFilesX86 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "vswhere.exe was not found at: $vswhere. Pass -MSBuildPath explicitly."
    }

    $output = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'MSBuild\**\Bin\MSBuild.exe'
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with exit code $LASTEXITCODE."
    }

    $candidates = @($output | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($candidates.Count -ne 1) {
        throw "Expected exactly one MSBuild.exe from vswhere.exe, found $($candidates.Count). Pass -MSBuildPath explicitly."
    }

    return (Resolve-Path -LiteralPath $candidates[0]).Path
}

$MSBuildPath = Resolve-MSBuildPath -RequestedPath $MSBuildPath
$DtIntUtilsRoot = if ([System.IO.Path]::IsPathRooted($DtIntUtilsRoot)) {
    [System.IO.Path]::GetFullPath($DtIntUtilsRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $DtIntUtilsRoot))
}
$dtIntUtilsBuild = Join-Path $DtIntUtilsRoot 'build.ps1'
$sdkDirectory = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin/$SdkVersion/x64"
$dxc = Join-Path $sdkDirectory 'dxc.exe'
$PackageDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $PSScriptRoot "bin/$Platform/$Configuration/package"
} elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
}
$outputDirectory = Join-Path $PSScriptRoot "bin/$Platform/$Configuration"
$toolDirectory = Join-Path $PSScriptRoot 'bin/tools'

function Invoke-BuildTool {
    param([string] $Executable, [string[]] $ToolArguments)

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.UseShellExecute = $false
    $startInfo.WorkingDirectory = $PSScriptRoot
    foreach ($argument in $ToolArguments) {
        [void] $startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "Build tool failed ($($process.ExitCode)): $Executable"
    }
}

function Build-Project {
    param(
        [string] $RelativePath
    )

    $project = Join-Path $PSScriptRoot $RelativePath
    if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
        throw "Project was not found: $project"
    }
    $arguments = @(
        $project,
        "/p:Configuration=$Configuration",
        "/p:Platform=$Platform",
        "/p:WindowsTargetPlatformVersion=$SdkVersion",
        "/p:DtIntUtilsRoot=$DtIntUtilsRoot",
        '/v:minimal',
        '/nologo'
    )
    Invoke-BuildTool $MSBuildPath $arguments
}

foreach ($file in @(
    $MSBuildPath,
    $dxc,
    (Join-Path $sdkDirectory 'dxcompiler.dll'),
    (Join-Path $sdkDirectory 'dxil.dll'),
    $dtIntUtilsBuild,
    (Join-Path $DtIntUtilsRoot 'include/dtintutils.h')
)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Build dependency was not found: $file"
    }
}
& $dtIntUtilsBuild -Configuration $Configuration -Platform $Platform -MSBuildPath $MSBuildPath
$dtIntUtilsLibrary = Join-Path $DtIntUtilsRoot "bin/$Platform/$Configuration/dtintutils-core.lib"
if (-not (Test-Path -LiteralPath $dtIntUtilsLibrary -PathType Leaf) -or
    (Get-Item -LiteralPath $dtIntUtilsLibrary).Length -eq 0) {
    throw "Darktide Internal Utils library was not found or is empty: $dtIntUtilsLibrary"
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Build-Project 'tools/assemble/assemble.vcxproj'
Build-Project 'tools/contracts/contracts.vcxproj'
foreach ($library in 'dxcompiler.dll', 'dxil.dll') {
    Copy-Item -LiteralPath (Join-Path $sdkDirectory $library) -Destination $toolDirectory
}
$assembler = Join-Path $toolDirectory 'assemble.exe'
foreach ($program in 'outline', 'combat', 'prop_outline') {
    Invoke-BuildTool $assembler @(
        (Join-Path $PSScriptRoot "shaders/$program.ll"),
        (Join-Path $outputDirectory "$program.dxil")
    )
}
Invoke-BuildTool $dxc @(
    '-T', 'ps_6_0', '-E', 'ps_main', '-O3',
    '-Fo', (Join-Path $outputDirectory 'composite.dxil'),
    (Join-Path $PSScriptRoot 'shaders/composite.hlsl')
)
Invoke-BuildTool (Join-Path $toolDirectory 'contracts.exe') @(
    (Join-Path $PSScriptRoot 'shaders/reference'),
    (Join-Path $PSScriptRoot 'obj/shader_contracts.generated.h')
)
Copy-Item -LiteralPath (Join-Path $sdkDirectory 'dxcompiler.dll') -Destination $outputDirectory
Build-Project 'GoodOldOutlines.vcxproj'
& $SignArtifact -Path (Join-Path $outputDirectory 'GoodOldOutlines.dll') -SigningConfig $SigningConfig -SigningAuthentication $SigningAuthentication
foreach ($name in 'GoodOldOutlines.dll', 'outline.dxil', 'combat.dxil', 'prop_outline.dxil', 'composite.dxil', 'dxcompiler.dll') {
    $file = Join-Path $outputDirectory $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
        (Get-Item -LiteralPath $file).Length -eq 0) {
        throw "Build output was not found or is empty: $file"
    }
    Get-FileHash -LiteralPath $file
}

$PackageBin = Join-Path $PackageDirectory 'bin'
New-Item -ItemType Directory -Force -Path $PackageBin | Out-Null
foreach ($name in 'GoodOldOutlines.dll', 'outline.dxil', 'combat.dxil', 'prop_outline.dxil', 'composite.dxil', 'dxcompiler.dll') {
    Copy-Item -LiteralPath (Join-Path $outputDirectory $name) -Destination $PackageBin -Force
}
