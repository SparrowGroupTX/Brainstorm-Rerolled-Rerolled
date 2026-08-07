#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$(cd -- "${script_dir}/.." && pwd)"
build_dir="${1:-${source_dir}/build-portable}"

cmake \
  -S "${source_dir}" \
  -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=ON \
  -DBRAINSTORM_NATIVE_OPTIMIZATIONS=OFF \
  -DBRAINSTORM_PGO_PHASE=OFF \
  -DBRAINSTORM_REQUIRE_MEGA_INDEX_ASSETS=ON
cmake --build "${build_dir}" --parallel
ctest --test-dir "${build_dir}" --output-on-failure

printf 'Portable Brainstorm native library built in %s\n' "${build_dir}"
