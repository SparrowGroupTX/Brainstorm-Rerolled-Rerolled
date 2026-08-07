$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$build = Join-Path $here "build"
cmake -S $here -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build $build --target charm_perkeo_mega_index_builder -j
