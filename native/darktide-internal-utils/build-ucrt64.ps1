param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [string] $Ucrt64Bin = "C:\msys64\ucrt64\bin"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$ProjectRoot = $PSScriptRoot
$Gcc = Join-Path -Path $Ucrt64Bin -ChildPath "gcc.exe"
$Ar = Join-Path -Path $Ucrt64Bin -ChildPath "ar.exe"
$OutputDir = Join-Path -Path $ProjectRoot -ChildPath "bin\ucrt64\$Configuration"
$ObjectDir = Join-Path -Path $ProjectRoot -ChildPath "obj\ucrt64\$Configuration"
$LibraryPath = Join-Path -Path $OutputDir -ChildPath "libdtintutils-core.a"

if (-not (Test-Path -LiteralPath $Gcc -PathType Leaf)) {
    throw "gcc.exe was not found at: $Gcc"
}

if (-not (Test-Path -LiteralPath $Ar -PathType Leaf)) {
    throw "ar.exe was not found at: $Ar"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $ObjectDir | Out-Null
$env:PATH = "$Ucrt64Bin;$env:PATH"

$Sources = @(
    [pscustomobject]@{ Path = "src\analysis.c"; Object = "analysis.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\hooks.c"; Object = "hooks.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\locator.c"; Object = "locator.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\locator_common.c"; Object = "locator_common.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\locator_sources.c"; Object = "locator_sources.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\memory.c"; Object = "memory.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "src\scan.c"; Object = "scan.o"; ThirdParty = $false }
    [pscustomobject]@{ Path = "third_party\minhook\src\buffer.c"; Object = "minhook_buffer.o"; ThirdParty = $true }
    [pscustomobject]@{ Path = "third_party\minhook\src\hook.c"; Object = "minhook_hook.o"; ThirdParty = $true }
    [pscustomobject]@{ Path = "third_party\minhook\src\trampoline.c"; Object = "minhook_trampoline.o"; ThirdParty = $true }
    [pscustomobject]@{ Path = "third_party\minhook\src\hde\hde64.c"; Object = "minhook_hde64.o"; ThirdParty = $true }
)

$ZydisSourceNames = @(
    "Decoder"
    "DecoderData"
    "Disassembler"
    "Encoder"
    "EncoderData"
    "Formatter"
    "FormatterATT"
    "FormatterBase"
    "FormatterBuffer"
    "FormatterIntel"
    "MetaInfo"
    "Mnemonic"
    "Register"
    "Segment"
    "SharedData"
    "String"
    "Utils"
    "Zydis"
)
$ZydisSources = foreach ($SourceName in $ZydisSourceNames) {
    [pscustomobject]@{
        Path = "third_party\zydis\src\$SourceName.c"
        Object = "zydis_$SourceName.o"
        ThirdParty = $true
    }
}

$ZycoreSourceNames = @(
    "Allocator"
    "ArgParse"
    "Bitset"
    "Format"
    "List"
    "String"
    "Vector"
    "Zycore"
    "API\Memory"
    "API\Process"
    "API\Synchronization"
    "API\Terminal"
    "API\Thread"
)
$ZycoreSources = foreach ($SourceName in $ZycoreSourceNames) {
    [pscustomobject]@{
        Path = "third_party\zydis\dependencies\zycore\src\$SourceName.c"
        Object = "zycore_$($SourceName.Replace('\', '_')).o"
        ThirdParty = $true
    }
}

$Sources += $ZydisSources
$Sources += $ZycoreSources

$IncludeDirectories = @(
    (Join-Path -Path $ProjectRoot -ChildPath "include")
    (Join-Path -Path $ProjectRoot -ChildPath "third_party\zydis\include")
    (Join-Path -Path $ProjectRoot -ChildPath "third_party\zydis\src")
    (Join-Path -Path $ProjectRoot -ChildPath "third_party\zydis\dependencies\zycore\include")
    (Join-Path -Path $ProjectRoot -ChildPath "third_party\minhook\include")
    (Join-Path -Path $ProjectRoot -ChildPath "third_party\minhook\src")
)

$ConfigurationFlags = if ($Configuration -eq "Debug") {
    @("-O0", "-g3")
} else {
    @("-O2", "-DNDEBUG", "-ffunction-sections", "-fdata-sections")
}

$Objects = foreach ($Source in $Sources) {
    $SourcePath = Join-Path -Path $ProjectRoot -ChildPath $Source.Path
    $ObjectPath = Join-Path -Path $ObjectDir -ChildPath $Source.Object
    $CompileArgs = @(
        "-c"
        $SourcePath
        "-o"
        $ObjectPath
        "-std=c17"
        "-m64"
        "-DWIN32_LEAN_AND_MEAN"
        "-DNOMINMAX"
        "-D_CRT_SECURE_NO_WARNINGS"
        "-DZYCORE_STATIC_BUILD"
        "-DZYDIS_STATIC_BUILD"
    )

    foreach ($IncludeDirectory in $IncludeDirectories) {
        $CompileArgs += "-I$IncludeDirectory"
    }
    $CompileArgs += $ConfigurationFlags
    $CompileArgs += if ($Source.ThirdParty) { "-w" } else { @("-Wall", "-Wextra") }

    & $Gcc @CompileArgs
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        throw "gcc.exe failed with exit code $ExitCode while compiling $SourcePath"
    }

    $ObjectPath
}

if (Test-Path -LiteralPath $LibraryPath -PathType Leaf) {
    Remove-Item -LiteralPath $LibraryPath -Force
}

$ArchiveArgs = @("rcs", $LibraryPath) + $Objects
& $Ar @ArchiveArgs
$ExitCode = $LASTEXITCODE
if ($ExitCode -ne 0) {
    throw "ar.exe failed with exit code $ExitCode"
}

if (-not (Test-Path -LiteralPath $LibraryPath -PathType Leaf) -or
    (Get-Item -LiteralPath $LibraryPath).Length -eq 0) {
    throw "Build output was not found or is empty: $LibraryPath"
}

Write-Host $LibraryPath
