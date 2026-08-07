$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\.."
$Output = Join-Path $PSScriptRoot "inversion_math_probe.exe"
g++ -O3 -std=c++20 -march=native `
  -DBRAINSTORM_OPENING_BATCH_AVX2 `
  -DBRAINSTORM_OPENING_BATCH_AVX512 `
  (Join-Path $PSScriptRoot "inversion_math_probe.cpp") `
  (Join-Path $Root "src\util.cpp") `
  (Join-Path $Root "src\seed.cpp") `
  (Join-Path $Root "src\opening_batch.cpp") `
  (Join-Path $Root "src\opening_batch_avx2.cpp") `
  (Join-Path $Root "src\opening_batch_avx512.cpp") `
  -o $Output
if ($LASTEXITCODE -ne 0) { throw "compile failed with exit code $LASTEXITCODE" }
Write-Output $Output

$IndexOutput = Join-Path $PSScriptRoot "candidate_index_probe.exe"
g++ -O3 -std=c++20 -march=native `
  -DBRAINSTORM_OPENING_BATCH_AVX2 `
  -DBRAINSTORM_OPENING_BATCH_AVX512 `
  (Join-Path $PSScriptRoot "candidate_index_probe.cpp") `
  (Join-Path $Root "src\util.cpp") `
  (Join-Path $Root "src\seed.cpp") `
  (Join-Path $Root "src\opening_batch.cpp") `
  (Join-Path $Root "src\opening_batch_avx2.cpp") `
  (Join-Path $Root "src\opening_batch_avx512.cpp") `
  -o $IndexOutput
if ($LASTEXITCODE -ne 0) { throw "compile failed with exit code $LASTEXITCODE" }
Write-Output $IndexOutput
