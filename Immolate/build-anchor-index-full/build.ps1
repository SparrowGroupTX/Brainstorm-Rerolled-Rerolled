$ErrorActionPreference = "Stop"
$BuildDirectory = Join-Path $PSScriptRoot "build"
cmake -S $PSScriptRoot -B $BuildDirectory -G Ninja -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed: $LASTEXITCODE" }
cmake --build $BuildDirectory --parallel
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
Write-Output (Join-Path $BuildDirectory "anchor_index_builder.exe")

