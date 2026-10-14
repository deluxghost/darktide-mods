param(
    [ValidateSet('Release')][string] $Configuration = 'Release',
    [ValidateSet('x64')][string] $Platform = 'x64',
    [string] $SdkVersion = '10.0.26100.0',
    [string] $MSBuildPath = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$sdkDirectory = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin/$SdkVersion/x64"
$dxc = Join-Path $sdkDirectory 'dxc.exe'
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
    param([string] $RelativePath)

    $project = Join-Path $PSScriptRoot $RelativePath
    if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
        throw "Project was not found: $project"
    }
    Invoke-BuildTool $MSBuildPath @(
        $project,
        "/p:Configuration=$Configuration",
        "/p:Platform=$Platform",
        "/p:WindowsTargetPlatformVersion=$SdkVersion",
        '/v:minimal',
        '/nologo'
    )
}

foreach ($file in @(
    $MSBuildPath,
    $dxc,
    (Join-Path $sdkDirectory 'dxcompiler.dll'),
    (Join-Path $sdkDirectory 'dxil.dll'),
    (Join-Path $PSScriptRoot '../darktide-internal-utils/include/dtintutils.h'),
    (Join-Path $PSScriptRoot '../darktide-internal-utils/bin/x64/Release/dtintutils-core.lib')
)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Build dependency was not found: $file"
    }
}
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Build-Project 'tools/assemble/assemble.vcxproj'
Build-Project 'tools/contracts/contracts.vcxproj'
foreach ($library in 'dxcompiler.dll', 'dxil.dll') {
    Copy-Item -LiteralPath (Join-Path $sdkDirectory $library) -Destination $toolDirectory
}
$assembler = Join-Path $toolDirectory 'assemble.exe'
foreach ($program in 'outline', 'combat') {
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
foreach ($name in 'GoodOldOutlines.dll', 'outline.dxil', 'combat.dxil', 'composite.dxil', 'dxcompiler.dll') {
    $file = Join-Path $outputDirectory $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Build output was not found: $file"
    }
    Get-FileHash -LiteralPath $file
}
