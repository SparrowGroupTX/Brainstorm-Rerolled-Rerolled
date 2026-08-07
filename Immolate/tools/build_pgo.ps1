[CmdletBinding()]
param(
    [string]$BuildDirectory = "",
    [string]$Generator = "Ninja",
    [string]$Compiler = "g++",
    [switch]$Portable
)

$ErrorActionPreference = "Stop"
$sourceDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $sourceDirectory "build-pgo"
}
$buildPath = [IO.Path]::GetFullPath($BuildDirectory)
$profilePath = [IO.Path]::GetFullPath((Join-Path $buildPath "profile-data"))
$buildRoot = [IO.Path]::GetPathRoot($buildPath).TrimEnd(
    [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$trimmedBuildPath = $buildPath.TrimEnd(
    [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

if ($buildPath -eq $sourceDirectory) {
    throw "The PGO build must be out of source."
}
if ($trimmedBuildPath -eq $buildRoot) {
    throw "A filesystem root cannot be used as the PGO build directory."
}
if (-not $profilePath.StartsWith($buildPath + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "The profile directory must stay inside the PGO build directory."
}

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

function Get-ProfiledSourceState {
    $trackedInputs = @(
        (Join-Path $sourceDirectory "CMakeLists.txt"),
        (Join-Path $sourceDirectory "tools\brainstorm_pgo_train.cpp")
    ) + @(Get-ChildItem -LiteralPath (Join-Path $sourceDirectory "src") `
        -Recurse -File | ForEach-Object { $_.FullName }) + `
        @(Get-ChildItem -LiteralPath (Join-Path $sourceDirectory "tests") `
        -Recurse -File | ForEach-Object { $_.FullName })

    return (($trackedInputs | Sort-Object | ForEach-Object {
        "$_=$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash)"
    }) -join "`n")
}

# Stale counters cannot be safely combined with a newly instrumented binary.
# This exact path is fixed beneath the validated build directory above.
if (Test-Path -LiteralPath $profilePath) {
    $profileItem = Get-Item -LiteralPath $profilePath -Force
    if (($profileItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to clear a profile directory that is a link or junction."
    }
    Remove-Item -LiteralPath $profilePath -Recurse -Force
}

$nativeValue = if ($Portable) { "OFF" } else { "ON" }
$sourceState = Get-ProfiledSourceState
$commonConfigure = @(
    "-S", $sourceDirectory,
    "-B", $buildPath,
    "-G", $Generator,
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_CXX_COMPILER=$Compiler",
    "-DBUILD_TESTING=ON",
    "-DBRAINSTORM_NATIVE_OPTIMIZATIONS=$nativeValue",
    "-DBRAINSTORM_REQUIRE_MEGA_INDEX_ASSETS=ON",
    "-DBRAINSTORM_PGO_PROFILE_DIR=$profilePath"
)

Write-Host "Configuring the profile-generation build..."
Invoke-Checked cmake ($commonConfigure + "-DBRAINSTORM_PGO_PHASE=GENERATE")
Invoke-Checked cmake @("--build", $buildPath, "--parallel")
Invoke-Checked ctest @("--test-dir", $buildPath, "-C", "Release", "--output-on-failure")

$trainerCandidates = @(
    (Join-Path $buildPath "brainstorm_pgo_train.exe"),
    (Join-Path $buildPath "brainstorm_pgo_train"),
    (Join-Path $buildPath "Release\brainstorm_pgo_train.exe")
)
$trainer = $trainerCandidates | Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($trainer)) {
    throw "The PGO training executable was not produced."
}

Write-Host "Training with representative single-thread workloads..."
Invoke-Checked $trainer @()

if ((Get-ProfiledSourceState) -ne $sourceState) {
    throw "Profiled sources changed during training. Rerun after edits stop; GCC cannot safely consume counters from a different source revision."
}

$profileCounters = @(Get-ChildItem -LiteralPath $profilePath -Recurse -File |
    Where-Object { $_.Extension -eq ".gcda" })
if ($profileCounters.Count -eq 0) {
    throw "Training completed without producing GCC profile counters."
}

Write-Host "Reconfiguring the same object paths to consume the profiles..."
Invoke-Checked cmake ($commonConfigure + "-DBRAINSTORM_PGO_PHASE=USE")
Invoke-Checked cmake @("--build", $buildPath, "--parallel")
Invoke-Checked ctest @("--test-dir", $buildPath, "-C", "Release", "--output-on-failure")

Write-Host "Optimized build ready at $buildPath"
