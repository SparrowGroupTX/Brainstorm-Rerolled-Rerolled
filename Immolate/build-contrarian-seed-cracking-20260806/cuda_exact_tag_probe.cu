// Diagnostic-only exact binary64 CUDA probe for Balatro's initial Tag1 roll.
// It is deliberately not part of the production build.

#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

constexpr std::uint64_t kDomain = 2318107019761ULL;
constexpr int kGroupsPerBlock = 7;
constexpr int kSeedsPerGroup = 35;
constexpr int kActiveThreads = kGroupsPerBlock * kSeedsPerGroup;

__device__ __constant__ std::uint64_t kIdCoeff[8] = {
    66231629136ULL, 1892332261ULL, 54066636ULL, 1544761ULL,
    44136ULL, 1261ULL, 36ULL, 1ULL};

__host__ __device__ constexpr unsigned char seedCharacter(unsigned digit) {
  return digit < 9 ? static_cast<unsigned char>('1' + digit)
                   : static_cast<unsigned char>('A' + digit - 9);
}

__device__ __forceinline__ double addRn(double a, double b) {
  return __dadd_rn(a, b);
}

__device__ __forceinline__ double mulRn(double a, double b) {
  return __dmul_rn(a, b);
}

__device__ __forceinline__ double divRn(double a, double b) {
  return __ddiv_rn(a, b);
}

__device__ __forceinline__ double fractPositive(double value) {
  return addRn(value, -floor(value));
}

__device__ __forceinline__ double pseudostep(
    double value, double character, int position) {
  double next = divRn(1.1239285023, value);
  next = mulRn(next, character);
  next = mulRn(next, 3.141592653589793116);
  next = addRn(
      next, mulRn(3.141592653589793116, static_cast<double>(position)));
  return fractPositive(next);
}

__device__ __forceinline__ double round13(double value) {
  constexpr double precision = 10000000000000.0;
  const double normal = divRn(round(mulRn(value, precision)), precision);
  const double previous = nextafter(value, -1.0);
  const double previousNormal =
      divRn(round(mulRn(previous, precision)), precision);
  if (normal == previousNormal) {
    return normal;
  }
  constexpr double twoPrecision = 8192.0;
  constexpr double fivePrecision = 1220703125.0;
  const double truncated = mulRn(
      fractPositive(mulRn(value, twoPrecision)), fivePrecision);
  const double integer = floor(mulRn(value, precision))
      + (fractPositive(truncated) >= 0.5 ? 1.0 : 0.0);
  return divRn(integer, precision);
}

__device__ __forceinline__ double advanceNode(double value) {
  value = addRn(mulRn(value, 1.72431234), 2.134453429141);
  return round13(fractPositive(value));
}

template <int A, int B, int C, int MaskShift>
__device__ __forceinline__ std::uint64_t advanceWord(std::uint64_t value) {
  return (((value << A) ^ value) >> B)
      ^ ((value & (~std::uint64_t{0} << MaskShift)) << C);
}

__device__ __forceinline__ int initialTagCategory(
    double hashedSeed, double tagSeedHash) {
  double tagValue = tagSeedHash;
  tagValue = pseudostep(tagValue, static_cast<double>('1'), 4);
  tagValue = pseudostep(tagValue, static_cast<double>('g'), 3);
  tagValue = pseudostep(tagValue, static_cast<double>('a'), 2);
  tagValue = pseudostep(tagValue, static_cast<double>('T'), 1);
  tagValue = advanceNode(tagValue);
  double d = mulRn(addRn(tagValue, hashedSeed), 0.5);

  const std::uint64_t minimums[4] = {
      std::uint64_t{1} << 1, std::uint64_t{1} << 6,
      std::uint64_t{1} << 9, std::uint64_t{1} << 17};
  std::uint64_t state[4];
#pragma unroll
  for (int index = 0; index < 4; ++index) {
    d = addRn(
        mulRn(d, 3.14159265358979323846), 2.7182818284590452354);
    std::uint64_t bits = static_cast<std::uint64_t>(__double_as_longlong(d));
    if (bits < minimums[index]) {
      bits += minimums[index];
    }
    state[index] = bits;
  }

#pragma unroll
  for (int step = 0; step < 11; ++step) {
    state[0] = advanceWord<31, 45, 18, 1>(state[0]);
    state[1] = advanceWord<19, 30, 28, 6>(state[1]);
    state[2] = advanceWord<24, 48, 7, 9>(state[2]);
    state[3] = advanceWord<21, 39, 8, 17>(state[3]);
  }
  constexpr std::uint64_t mantissaMask = (std::uint64_t{1} << 52) - 1;
  constexpr std::uint64_t oneExponent = 0x3ff0000000000000ULL;
  const std::uint64_t bits =
      (state[0] ^ state[1] ^ state[2] ^ state[3]) & mantissaMask;
  const double random = addRn(
      __longlong_as_double(static_cast<long long>(bits | oneExponent)), -1.0);
  return static_cast<int>(mulRn(random, 24.0));
}

__global__ void rawSeedKernel(
    std::uint64_t startId, std::uint64_t count, std::uint8_t *categories,
    unsigned long long *charmCount) {
  const std::uint64_t offset = static_cast<std::uint64_t>(blockIdx.x)
      * blockDim.x + threadIdx.x;
  __shared__ unsigned blockCharm;
  if (threadIdx.x == 0) {
    blockCharm = 0;
  }
  __syncthreads();
  if (offset < count) {
    std::uint64_t id = (startId + offset) % kDomain;
    unsigned char characters[8];
    int length = 0;
#pragma unroll
    for (int position = 0; position < 8; ++position) {
      if (id > 0) {
        const unsigned digit = static_cast<unsigned>(
            (id - 1) / kIdCoeff[position]);
        id -= 1 + static_cast<std::uint64_t>(digit) * kIdCoeff[position];
        characters[position] = seedCharacter(digit);
        ++length;
      }
    }
    double hashed = 1.0;
    double tagSeedHash = 1.0;
#pragma unroll
    for (int position = 0; position < 8; ++position) {
      if (position < length) {
        hashed = pseudostep(
            hashed, static_cast<double>(characters[position]),
            length - position);
        tagSeedHash = pseudostep(
            tagSeedHash, static_cast<double>(characters[position]),
            4 + length - position);
      }
    }
    const int category = initialTagCategory(hashed, tagSeedHash);
    if (categories != nullptr) {
      categories[offset] = static_cast<std::uint8_t>(category);
    }
    if (category == 10) {
      atomicAdd(&blockCharm, 1u);
    }
  }
  __syncthreads();
  if (threadIdx.x == 0) {
    atomicAdd(charmCount, static_cast<unsigned long long>(blockCharm));
  }
}

__global__ void groupedLengthEightKernel(
    std::uint64_t firstGroup, std::uint64_t groupCount,
    std::uint8_t *categories, unsigned long long *charmCount) {
  __shared__ double prefix0[kGroupsPerBlock];
  __shared__ double prefix4[kGroupsPerBlock];
  __shared__ unsigned blockCharm;
  const int thread = threadIdx.x;
  const int localGroup = thread / kSeedsPerGroup;
  const int lastDigit = thread % kSeedsPerGroup;
  const std::uint64_t groupOffset =
      static_cast<std::uint64_t>(blockIdx.x) * kGroupsPerBlock
      + static_cast<unsigned>(localGroup);
  if (thread == 0) {
    blockCharm = 0;
  }
  if (thread < kActiveThreads && lastDigit == 0 && groupOffset < groupCount) {
    std::uint64_t rank = firstGroup + groupOffset;
    unsigned char digits[7];
    // Decode group rank in canonical-ID order (digit 0 most significant,
    // digit 6 least significant).
#pragma unroll
    for (int position = 6; position >= 0; --position) {
      digits[position] = static_cast<unsigned char>(rank % 35);
      rank /= 35;
    }
    double hash0 = 1.0;
    double hash4 = 1.0;
#pragma unroll
    for (int position = 0; position < 7; ++position) {
      const double character = static_cast<double>(
          seedCharacter(digits[position]));
      hash0 = pseudostep(hash0, character, 8 - position);
      hash4 = pseudostep(hash4, character, 12 - position);
    }
    prefix0[localGroup] = hash0;
    prefix4[localGroup] = hash4;
  }
  __syncthreads();

  if (thread < kActiveThreads && groupOffset < groupCount) {
    const double character = static_cast<double>(seedCharacter(lastDigit));
    const double hashed = pseudostep(prefix0[localGroup], character, 1);
    const double tagSeedHash = pseudostep(prefix4[localGroup], character, 5);
    const int category = initialTagCategory(hashed, tagSeedHash);
    const std::uint64_t output = groupOffset * kSeedsPerGroup
        + static_cast<unsigned>(lastDigit);
    if (categories != nullptr) {
      categories[output] = static_cast<std::uint8_t>(category);
    }
    if (category == 10) {
      atomicAdd(&blockCharm, 1u);
    }
  }
  __syncthreads();
  if (thread == 0) {
    atomicAdd(charmCount, static_cast<unsigned long long>(blockCharm));
  }
}

void check(cudaError_t result, const char *operation) {
  if (result != cudaSuccess) {
    std::cerr << operation << ": " << cudaGetErrorString(result) << '\n';
    std::exit(2);
  }
}

std::vector<std::uint8_t> readFile(const std::string &path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    std::cerr << "cannot open fixture: " << path << '\n';
    std::exit(2);
  }
  const auto size = input.tellg();
  input.seekg(0);
  std::vector<std::uint8_t> bytes(static_cast<std::size_t>(size));
  input.read(reinterpret_cast<char *>(bytes.data()), size);
  if (!input) {
    std::cerr << "cannot read fixture: " << path << '\n';
    std::exit(2);
  }
  return bytes;
}

} // namespace

int main(int argc, char **argv) {
  if (argc < 4) {
    std::cerr << "usage: " << argv[0]
              << " raw <start-id> <count> [fixture] [iterations]\n"
              << "   or: " << argv[0]
              << " group <first-group> <group-count> [fixture] [iterations]\n";
    return 2;
  }
  const std::string mode = argv[1];
  const std::uint64_t start = std::strtoull(argv[2], nullptr, 10);
  const std::uint64_t units = std::strtoull(argv[3], nullptr, 10);
  const std::string fixture = argc > 4 ? argv[4] : std::string{};
  const int iterations = argc > 5 ? std::max(1, std::atoi(argv[5])) : 1;
  if (mode != "raw" && mode != "group") {
    std::cerr << "mode must be raw or group\n";
    return 2;
  }
  const std::uint64_t seeds = mode == "raw" ? units : units * 35;
  if (seeds == 0) {
    std::cerr << "count must be positive\n";
    return 2;
  }

  const auto wallStart = std::chrono::steady_clock::now();
  check(cudaSetDevice(0), "cudaSetDevice");
  std::uint8_t *deviceCategories = nullptr;
  if (!fixture.empty()) {
    check(cudaMalloc(&deviceCategories, static_cast<std::size_t>(seeds)),
          "cudaMalloc categories");
  }
  unsigned long long *deviceCharm = nullptr;
  check(cudaMalloc(&deviceCharm, sizeof(*deviceCharm)), "cudaMalloc count");
  check(cudaMemset(deviceCharm, 0, sizeof(*deviceCharm)), "cudaMemset count");
  const auto setupDone = std::chrono::steady_clock::now();

  const int threads = mode == "raw" ? 256 : 256;
  const std::uint64_t blocks64 = mode == "raw"
      ? (units + threads - 1) / threads
      : (units + kGroupsPerBlock - 1) / kGroupsPerBlock;
  if (blocks64 > static_cast<std::uint64_t>(0x7fffffff)) {
    std::cerr << "probe range too large for one launch\n";
    return 2;
  }
  const int blocks = static_cast<int>(blocks64);

  // One warmup pays context/JIT costs outside the event timing while remaining
  // included in the reported wall-clock setup-to-result time.
  if (mode == "raw") {
    rawSeedKernel<<<blocks, threads>>>(start, units, deviceCategories, deviceCharm);
  } else {
    groupedLengthEightKernel<<<blocks, threads>>>(
        start, units, deviceCategories, deviceCharm);
  }
  check(cudaGetLastError(), "warmup launch");
  check(cudaDeviceSynchronize(), "warmup synchronize");
  check(cudaMemset(deviceCharm, 0, sizeof(*deviceCharm)), "reset count");

  cudaEvent_t begin{};
  cudaEvent_t end{};
  check(cudaEventCreate(&begin), "cudaEventCreate begin");
  check(cudaEventCreate(&end), "cudaEventCreate end");
  check(cudaEventRecord(begin), "cudaEventRecord begin");
  for (int iteration = 0; iteration < iterations; ++iteration) {
    if (mode == "raw") {
      rawSeedKernel<<<blocks, threads>>>(
          start, units, deviceCategories, deviceCharm);
    } else {
      groupedLengthEightKernel<<<blocks, threads>>>(
          start, units, deviceCategories, deviceCharm);
    }
  }
  check(cudaGetLastError(), "timed launch");
  check(cudaEventRecord(end), "cudaEventRecord end");
  check(cudaEventSynchronize(end), "cudaEventSynchronize end");
  float kernelMilliseconds = 0.0f;
  check(cudaEventElapsedTime(&kernelMilliseconds, begin, end),
        "cudaEventElapsedTime");

  unsigned long long charm = 0;
  check(cudaMemcpy(
            &charm, deviceCharm, sizeof(charm), cudaMemcpyDeviceToHost),
        "cudaMemcpy count");
  std::vector<std::uint8_t> actual;
  if (!fixture.empty()) {
    actual.resize(static_cast<std::size_t>(seeds));
    check(cudaMemcpy(actual.data(), deviceCategories, actual.size(),
                     cudaMemcpyDeviceToHost),
          "cudaMemcpy categories");
  }
  const auto copiedDone = std::chrono::steady_clock::now();

  std::size_t mismatches = 0;
  if (!fixture.empty()) {
    const auto expected = readFile(fixture);
    if (expected.size() != actual.size()) {
      std::cerr << "fixture size=" << expected.size()
                << " expected=" << actual.size() << '\n';
      return 2;
    }
    for (std::size_t index = 0; index < actual.size(); ++index) {
      if (actual[index] != expected[index]) {
        if (mismatches < 20) {
          std::cerr << "mismatch index=" << index
                    << " cpu=" << static_cast<int>(expected[index])
                    << " gpu=" << static_cast<int>(actual[index]) << '\n';
        }
        ++mismatches;
      }
    }
  }
  const auto wallDone = std::chrono::steady_clock::now();
  const double setupMilliseconds = std::chrono::duration<double, std::milli>(
      setupDone - wallStart).count();
  const double copyMilliseconds = std::chrono::duration<double, std::milli>(
      copiedDone - setupDone).count() - kernelMilliseconds;
  const double wallMilliseconds = std::chrono::duration<double, std::milli>(
      wallDone - wallStart).count();
  const double totalSeeds = static_cast<double>(seeds) * iterations;
  const double rate = totalSeeds / (kernelMilliseconds / 1000.0);
  std::cout << "mode=" << mode << " seeds=" << seeds
            << " iterations=" << iterations
            << " kernel_ms=" << kernelMilliseconds
            << " rate_seeds_s=" << rate
            << " setup_ms=" << setupMilliseconds
            << " post_kernel_copy_ms=" << copyMilliseconds
            << " wall_ms=" << wallMilliseconds
            << " charm_accumulated=" << charm
            << " mismatches=" << mismatches << '\n';

  cudaEventDestroy(begin);
  cudaEventDestroy(end);
  cudaFree(deviceCategories);
  cudaFree(deviceCharm);
  return mismatches == 0 ? 0 : 1;
}
