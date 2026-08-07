// Diagnostic-only exact A/B: established tag-first CUDA gate versus the same
// independently keyed predicates evaluated Perkeo-first.

#define main brainstorm_original_cuda_probe_main
#include "../build-gpu-probe/opening_gate_cuda.cu"
#undef main

#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

HD bool openingGatePerkeoFirst(long long seedId) {
  constexpr char tagKey[] = "Tag1";
  constexpr char soulKey[] = "soul_Tarot1";
  constexpr char legendaryKey[] = "Joker4";
  const CompactSeed seed = seedFromId(seedId);
  const double hashedSeed = seedHash(seed, 0);

  // This stream is independently keyed.  Evaluating it before the other
  // conjuncts cannot advance or mutate either the tag or Soul stream.
  const int legendary = static_cast<int>(mulRn(
      luaRandom(freshNode(seed, hashedSeed, legendaryKey, 6)), 5.0));
  if (legendary != 4) {
    return false;
  }

  int resample = 1;
  while (true) {
    char dynamicKey[16];
    const char *key = tagKey;
    int keyLength = 4;
    if (resample > 1) {
      keyLength = appendResampleNumber(dynamicKey, resample);
      key = dynamicKey;
    }
    const int tag = static_cast<int>(
        mulRn(luaRandom(freshNode(seed, hashedSeed, key, keyLength)), 24.0));
    if (!lockedTag(tag) || resample >= 1000) {
      if (tag != 10) {
        return false;
      }
      break;
    }
    ++resample;
  }

  double soulState = keyHash(soulKey, 11, seedHash(seed, 11));
  bool foundSoul = false;
  for (int card = 0; card < 5; ++card) {
    soulState = advancedState(soulState);
    const double node = mulRn(addRn(soulState, hashedSeed), 0.5);
    if (luaRandom(node) > SOUL_THRESHOLD) {
      foundSoul = true;
      break;
    }
  }
  return foundSoul;
}

__global__ void perkeoFirstKernel(long long startId, int count,
                                  u32 *survivors, u32 *survivorCount) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count && openingGatePerkeoFirst(startId + index)) {
    const u32 output = atomicAdd(survivorCount, 1u);
    survivors[output] = static_cast<u32>(index);
  }
}

std::vector<u32> copySortedSurvivors(u32 *deviceSurvivors,
                                     u32 *deviceCount) {
  u32 count = 0;
  checkCuda(cudaMemcpy(&count, deviceCount, sizeof(count),
                       cudaMemcpyDeviceToHost), "copy survivor count");
  std::vector<u32> result(count);
  if (count != 0) {
    checkCuda(cudaMemcpy(result.data(), deviceSurvivors,
                         sizeof(u32) * result.size(),
                         cudaMemcpyDeviceToHost), "copy survivors");
  }
  std::sort(result.begin(), result.end());
  return result;
}

struct TimedResult {
  double kernelSeconds = 0.0;
  double endToEndSeconds = 0.0;
  u32 survivors = 0;
};

TimedResult timeKernel(bool perkeoFirst, long long startId, int count,
                       int repeats, u32 *deviceSurvivors, u32 *deviceCount,
                       u32 *hostSurvivors, u32 *hostCount) {
  const int blocks = (count + 255) / 256;
  cudaEvent_t begin{};
  cudaEvent_t end{};
  checkCuda(cudaEventCreate(&begin), "create begin event");
  checkCuda(cudaEventCreate(&end), "create end event");

  checkCuda(cudaEventRecord(begin), "record begin event");
  for (int repeat = 0; repeat < repeats; ++repeat) {
    checkCuda(cudaMemsetAsync(deviceCount, 0, sizeof(u32)), "clear count");
    const long long repeatStart = startId
        + static_cast<long long>(repeat) * count;
    if (perkeoFirst) {
      perkeoFirstKernel<<<blocks, 256>>>(
          repeatStart, count, deviceSurvivors, deviceCount);
    } else {
      openingKernel<<<blocks, 256>>>(
          repeatStart, count, deviceSurvivors, deviceCount);
    }
  }
  checkCuda(cudaGetLastError(), "timed kernel launch");
  checkCuda(cudaEventRecord(end), "record end event");
  checkCuda(cudaEventSynchronize(end), "synchronize end event");
  float milliseconds = 0.0f;
  checkCuda(cudaEventElapsedTime(&milliseconds, begin, end), "event elapsed");

  const auto wallBegin = std::chrono::steady_clock::now();
  u64 totalSurvivors = 0;
  for (int repeat = 0; repeat < repeats; ++repeat) {
    checkCuda(cudaMemsetAsync(deviceCount, 0, sizeof(u32)), "clear count e2e");
    const long long repeatStart = startId
        + static_cast<long long>(repeat) * count;
    if (perkeoFirst) {
      perkeoFirstKernel<<<blocks, 256>>>(
          repeatStart, count, deviceSurvivors, deviceCount);
    } else {
      openingKernel<<<blocks, 256>>>(
          repeatStart, count, deviceSurvivors, deviceCount);
    }
    checkCuda(cudaMemcpyAsync(hostCount, deviceCount, sizeof(u32),
                              cudaMemcpyDeviceToHost), "copy count e2e");
    checkCuda(cudaStreamSynchronize(nullptr), "sync count e2e");
    if (*hostCount > static_cast<u32>(count)) {
      throw std::runtime_error("invalid survivor count");
    }
    if (*hostCount != 0) {
      checkCuda(cudaMemcpy(hostSurvivors, deviceSurvivors,
                           sizeof(u32) * *hostCount,
                           cudaMemcpyDeviceToHost), "copy list e2e");
    }
    totalSurvivors += *hostCount;
  }
  const double wallSeconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - wallBegin).count();
  cudaEventDestroy(end);
  cudaEventDestroy(begin);
  return {static_cast<double>(milliseconds) / 1000.0,
          wallSeconds, static_cast<u32>(totalSurvivors)};
}

} // namespace

int main() {
  try {
    std::cout << std::unitbuf;
    checkCuda(cudaSetDevice(0), "set device");
    checkCuda(cudaFree(nullptr), "initialize context");

    constexpr long long verifyStart = 1000000000000LL;
    constexpr int verifyCount = 1 << 20;
    std::vector<u32> hostTagFirst;
    std::vector<u32> hostPerkeoFirst;
    hostTagFirst.reserve(verifyCount / 3000 + 8);
    hostPerkeoFirst.reserve(verifyCount / 3000 + 8);
    for (int index = 0; index < verifyCount; ++index) {
      if (openingGate(verifyStart + index)) {
        hostTagFirst.push_back(static_cast<u32>(index));
      }
      if (openingGatePerkeoFirst(verifyStart + index)) {
        hostPerkeoFirst.push_back(static_cast<u32>(index));
      }
    }
    if (hostTagFirst != hostPerkeoFirst || hostTagFirst.size() != 231) {
      throw std::runtime_error("host reordered predicate mismatch");
    }
    std::cout << "host_order_parity_seeds=" << verifyCount
              << " hits=" << hostTagFirst.size() << " status=exact\n";

    constexpr int benchmarkCount = 100000000;
    constexpr int repeats = 3;
    // A 1/5000 hit rate needs only a tiny fraction of this allocation, but use
    // a conservative capacity so a diagnostic failure cannot overwrite it.
    constexpr std::size_t survivorCapacity = benchmarkCount / 100 + 4096;
    u32 *deviceSurvivors = nullptr;
    u32 *deviceCount = nullptr;
    u32 *hostSurvivors = nullptr;
    u32 *hostCount = nullptr;
    checkCuda(cudaMalloc(&deviceSurvivors,
                         sizeof(u32) * survivorCapacity), "allocate output");
    checkCuda(cudaMalloc(&deviceCount, sizeof(u32)), "allocate count");
    checkCuda(cudaHostAlloc(&hostSurvivors,
                            sizeof(u32) * survivorCapacity,
                            cudaHostAllocDefault), "allocate pinned output");
    checkCuda(cudaHostAlloc(&hostCount, sizeof(u32), cudaHostAllocDefault),
              "allocate pinned count");

    checkCuda(cudaMemset(deviceCount, 0, sizeof(u32)), "clear verify count");
    openingKernel<<<(verifyCount + 255) / 256, 256>>>(
        verifyStart, verifyCount, deviceSurvivors, deviceCount);
    auto gpuTagFirst = copySortedSurvivors(deviceSurvivors, deviceCount);
    checkCuda(cudaMemset(deviceCount, 0, sizeof(u32)), "clear verify count 2");
    perkeoFirstKernel<<<(verifyCount + 255) / 256, 256>>>(
        verifyStart, verifyCount, deviceSurvivors, deviceCount);
    auto gpuPerkeoFirst = copySortedSurvivors(deviceSurvivors, deviceCount);
    if (gpuTagFirst != hostTagFirst || gpuPerkeoFirst != hostTagFirst) {
      throw std::runtime_error("GPU reordered predicate mismatch");
    }
    std::cout << "gpu_order_parity_seeds=" << verifyCount
              << " hits=" << gpuTagFirst.size() << " status=exact\n";

    // Warm both instruction paths before paired timing.
    checkCuda(cudaMemset(deviceCount, 0, sizeof(u32)), "clear warmup count");
    openingKernel<<<(verifyCount + 255) / 256, 256>>>(
        verifyStart, verifyCount, deviceSurvivors, deviceCount);
    checkCuda(cudaMemset(deviceCount, 0, sizeof(u32)), "clear warmup count 2");
    perkeoFirstKernel<<<(verifyCount + 255) / 256, 256>>>(
        verifyStart, verifyCount, deviceSurvivors, deviceCount);
    checkCuda(cudaDeviceSynchronize(), "warmup sync");

    const TimedResult tagFirst = timeKernel(
        false, verifyStart, benchmarkCount, repeats,
        deviceSurvivors, deviceCount, hostSurvivors, hostCount);
    const TimedResult perkeoFirst = timeKernel(
        true, verifyStart, benchmarkCount, repeats,
        deviceSurvivors, deviceCount, hostSurvivors, hostCount);
    const double evaluations = static_cast<double>(benchmarkCount) * repeats;
    auto print = [&](const char *label, const TimedResult &result) {
      std::cout << label << " kernel_Mseeds_s=" << std::fixed
                << std::setprecision(2)
                << evaluations / result.kernelSeconds / 1.0e6
                << " e2e_Mseeds_s="
                << evaluations / result.endToEndSeconds / 1.0e6
                << " survivors=" << result.survivors << '\n';
    };
    print("tag_first", tagFirst);
    print("perkeo_first", perkeoFirst);
    std::cout << "kernel_speedup="
              << tagFirst.kernelSeconds / perkeoFirst.kernelSeconds
              << "x e2e_speedup="
              << tagFirst.endToEndSeconds / perkeoFirst.endToEndSeconds
              << "x\n";

    cudaFreeHost(hostCount);
    cudaFreeHost(hostSurvivors);
    cudaFree(deviceCount);
    cudaFree(deviceSurvivors);
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "perkeo-first CUDA probe failed: " << error.what() << '\n';
    return 1;
  }
}
