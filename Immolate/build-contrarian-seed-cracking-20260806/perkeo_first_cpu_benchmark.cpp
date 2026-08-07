#include "../src/opening_batch.hpp"
#include "../src/seed.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#if defined(BRAINSTORM_PRODUCTION_ORDER_AB)
void collectOpeningCharmSoulAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivors);
void collectOpeningCharmSoulAvx512ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivors, bool sharedInitialHashes);
#else
void collectOpeningCharmSoulPerkeoFirstAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivors);
#endif

namespace {

constexpr std::uint64_t kConfiguration =
    1u | (static_cast<std::uint64_t>(4 + 1) << 8u);
constexpr std::uint64_t kTotal = 4000000000ULL;
constexpr std::uint64_t kChunk = 4096;
constexpr int kWorkers = 36;
constexpr long long kStart = 1000000000000LL;

enum class Variant { TagFirst, PerkeoFirst };

struct Result {
  std::uint64_t survivors = 0;
  std::uint64_t checksum = 0;
  double seconds = 0.0;
};

void setAvx512Backend() {
#if defined(_WIN32)
  _putenv_s("BRAINSTORM_OPENING_BATCH_BACKEND", "avx512");
#else
  setenv("BRAINSTORM_OPENING_BATCH_BACKEND", "avx512", 1);
#endif
}

Result run(Variant variant) {
  std::atomic<std::uint64_t> next{0};
  std::atomic<bool> go{false};
  std::atomic<int> ready{0};
  std::vector<std::thread> threads;
  std::vector<std::uint64_t> counts(kWorkers, 0);
  std::vector<std::uint64_t> checksums(kWorkers, 0);
  threads.reserve(kWorkers);
  for (int worker = 0; worker < kWorkers; ++worker) {
    threads.emplace_back([&, worker]() {
      void *context = createOpeningCharmSoulBatchContext(kConfiguration);
      std::vector<std::uint32_t> offsets;
      offsets.reserve(kChunk / 3000 + 8);
      ready.fetch_add(1, std::memory_order_release);
      while (!go.load(std::memory_order_acquire)) {
        std::this_thread::yield();
      }
      while (true) {
        const std::uint64_t offset = next.fetch_add(
            kChunk, std::memory_order_relaxed);
        if (offset >= kTotal) {
          break;
        }
        const std::size_t count = static_cast<std::size_t>(
            std::min<std::uint64_t>(kChunk, kTotal - offset));
        if (variant == Variant::TagFirst) {
#if defined(BRAINSTORM_PRODUCTION_ORDER_AB)
          collectOpeningCharmSoulAvx512ForTesting(
              context, kStart + static_cast<long long>(offset), count,
              offsets, true);
#else
          collectOpeningCharmSoulCandidatesWithContext(
              context, kStart + static_cast<long long>(offset), count,
              offsets);
#endif
        } else {
#if defined(BRAINSTORM_PRODUCTION_ORDER_AB)
          collectOpeningCharmSoulAvx512(
              context, kStart + static_cast<long long>(offset), count,
              offsets);
#else
          collectOpeningCharmSoulPerkeoFirstAvx512(
              context, kStart + static_cast<long long>(offset), count,
              offsets);
#endif
        }
        counts[worker] += offsets.size();
        for (const std::uint32_t survivor : offsets) {
          checksums[worker] += offset + survivor;
        }
      }
      destroyOpeningCharmSoulBatchContext(context);
    });
  }
  while (ready.load(std::memory_order_acquire) != kWorkers) {
    std::this_thread::yield();
  }
  const auto begin = std::chrono::steady_clock::now();
  go.store(true, std::memory_order_release);
  for (auto &thread : threads) {
    thread.join();
  }
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - begin).count();
  Result result;
  result.seconds = seconds;
  for (int worker = 0; worker < kWorkers; ++worker) {
    result.survivors += counts[worker];
    result.checksum += checksums[worker];
  }
  return result;
}

bool verifyRange(long long start, std::size_t count,
                 OpeningCharmSoulCriteria criteria = {1, 4}) {
  const std::uint64_t configuration =
      static_cast<std::uint64_t>(criteria.minimumSoulCount)
      | (static_cast<std::uint64_t>(criteria.legendaryIndex + 1) << 8u);
  void *candidateContext = createOpeningCharmSoulBatchContext(configuration);
  std::vector<std::uint32_t> baseline;
  std::vector<std::uint32_t> candidate;
#if defined(BRAINSTORM_PRODUCTION_ORDER_AB)
  void *baselineContext = createOpeningCharmSoulBatchContext(configuration);
  collectOpeningCharmSoulAvx512ForTesting(
      baselineContext, start, count, baseline, true);
  collectOpeningCharmSoulAvx512(
      candidateContext, start, count, candidate);
  destroyOpeningCharmSoulBatchContext(baselineContext);
#else
  collectOpeningCharmSoulCandidatesWithBackend(
      start, count, baseline, criteria,
      OpeningCharmSoulBackend::Avx512);
  collectOpeningCharmSoulPerkeoFirstAvx512(
      candidateContext, start, count, candidate);
#endif
  destroyOpeningCharmSoulBatchContext(candidateContext);
  if (baseline != candidate) {
    std::cerr << "parity mismatch start=" << start << " count=" << count
              << " baseline=" << baseline.size()
              << " candidate=" << candidate.size() << '\n';
    return false;
  }
  std::cout << "parity start=" << start << " count=" << count
            << " souls=" << criteria.minimumSoulCount
            << " legendary=" << criteria.legendaryIndex
            << " survivors=" << baseline.size() << " exact\n";
  return true;
}

void printResult(const char *label, const Result &result) {
  std::cout << label << " seconds=" << std::fixed << std::setprecision(6)
            << result.seconds << " Mseeds_s="
            << (static_cast<double>(kTotal) / result.seconds / 1.0e6)
            << " survivors=" << result.survivors
            << " checksum=" << result.checksum << '\n';
}

} // namespace

int main(int argc, char **argv) {
  setAvx512Backend();
  bool exact = true;
  exact &= verifyRange(0, 1 << 20);
  exact &= verifyRange(kStart, 1 << 20);
  exact &= verifyRange(SEED_DOMAIN_SIZE - (1 << 19), 1 << 20);
  for (int souls = 1; souls <= 4; ++souls) {
    for (int legendary = 0; legendary < 5; ++legendary) {
      exact &= verifyRange(
          123456789012LL, 1 << 18,
          OpeningCharmSoulCriteria{souls, legendary});
    }
  }
  if (!exact) {
    return 2;
  }
  if (argc > 1 && std::string(argv[1]) == "verify-only") {
    std::cout << "verify_matrix=PASS\n";
    return 0;
  }

  // Paired order controls for temperature/frequency drift.
  const Result tagFirstA = run(Variant::TagFirst);
  const Result perkeoFirstA = run(Variant::PerkeoFirst);
  const Result perkeoFirstB = run(Variant::PerkeoFirst);
  const Result tagFirstB = run(Variant::TagFirst);
  printResult("tag_first_a", tagFirstA);
  printResult("perkeo_first_a", perkeoFirstA);
  printResult("perkeo_first_b", perkeoFirstB);
  printResult("tag_first_b", tagFirstB);
  if (tagFirstA.survivors != perkeoFirstA.survivors
      || tagFirstA.survivors != perkeoFirstB.survivors
      || tagFirstA.survivors != tagFirstB.survivors
      || tagFirstA.checksum != perkeoFirstA.checksum
      || tagFirstA.checksum != perkeoFirstB.checksum
      || tagFirstA.checksum != tagFirstB.checksum) {
    std::cerr << "benchmark result sets differ\n";
    return 3;
  }
  const double tagMedian = (tagFirstA.seconds + tagFirstB.seconds) * 0.5;
  const double perkeoMedian =
      (perkeoFirstA.seconds + perkeoFirstB.seconds) * 0.5;
  std::cout << "paired_mean_speedup=" << std::fixed << std::setprecision(4)
            << tagMedian / perkeoMedian << "x exact_results=true\n";
  return 0;
}
