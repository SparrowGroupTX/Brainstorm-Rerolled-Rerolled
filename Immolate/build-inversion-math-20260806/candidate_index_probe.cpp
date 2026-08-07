#include "../src/opening_batch.hpp"
#include "../src/seed.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

std::size_t uleb128Bytes(std::uint64_t value) {
  std::size_t bytes = 1;
  while (value >= 128) {
    value >>= 7;
    ++bytes;
  }
  return bytes;
}

std::uint64_t suffixKey(const Seed &seed) {
  std::uint64_t key = 0;
  for (int position = 0; position < 7; ++position) {
    key |= static_cast<std::uint64_t>(seed.seed[position] + 1)
        << (position * 6);
  }
  return key;
}

struct Stats {
  std::uint64_t seeds = 0;
  std::uint64_t survivors = 0;
  std::uint64_t fullLengthSurvivors = 0;
  std::uint64_t deltaBytes = 0;
  std::uint64_t gapsUnder128 = 0;
  std::uint64_t gapsUnder16384 = 0;
  std::uint64_t gapsUnder2097152 = 0;
  std::uint64_t maximumGap = 0;
  std::uint64_t occupiedSuffixGroups = 0;
  std::uint64_t multiHitSuffixGroups = 0;
  std::array<std::array<std::uint64_t, 35>, 8> digitHits{};
};

void printDigitUniformity(const Stats &stats) {
  for (int position = 0; position < 8; ++position) {
    const auto &counts = stats.digitHits[position];
    const double expected = static_cast<double>(
        std::accumulate(counts.begin(), counts.end(), std::uint64_t{0}))
        / counts.size();
    double chiSquare = 0.0;
    std::uint64_t minimum = std::numeric_limits<std::uint64_t>::max();
    std::uint64_t maximum = 0;
    for (std::uint64_t count : counts) {
      const double difference = static_cast<double>(count) - expected;
      chiSquare += difference * difference / expected;
      minimum = std::min(minimum, count);
      maximum = std::max(maximum, count);
    }
    std::cout << "digit_hits stored_position=" << position
              << " expected=" << expected
              << " min=" << minimum << " max=" << maximum
              << " chi_square_df34=" << chiSquare << '\n';
  }
}

} // namespace

int main(int argc, char **argv) {
  const std::uint64_t requested = argc > 1
      ? std::strtoull(argv[1], nullptr, 10)
      : 100000000ull;
  const std::uint64_t startId = argc > 2
      ? std::strtoull(argv[2], nullptr, 10)
      : 1000000000000ull;
  const std::size_t chunkSize = 1u << 20;
  const OpeningCharmSoulCriteria criteria{1, 4};
  void *context = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria(criteria));
  std::vector<std::uint32_t> offsets;
  offsets.reserve(chunkSize / 4000 + 64);
  Stats stats;
  bool havePrevious = false;
  std::uint64_t previousId = 0;
  std::vector<std::uint64_t> suffixGroups;
  suffixGroups.reserve(static_cast<std::size_t>(requested / 4000 + 64));

  const auto begin = std::chrono::steady_clock::now();
  for (std::uint64_t done = 0; done < requested;) {
    const std::size_t count = static_cast<std::size_t>(
        std::min<std::uint64_t>(chunkSize, requested - done));
    const long long blockStart = normalizeSeedId(
        static_cast<long long>(startId + done));
    collectOpeningCharmSoulCandidatesWithContext(
        context, blockStart, count, offsets);
    stats.seeds += count;
    stats.survivors += offsets.size();
    for (std::uint32_t offset : offsets) {
      const std::uint64_t id = static_cast<std::uint64_t>(
          normalizeSeedId(blockStart + offset));
      if (havePrevious && id > previousId) {
        const std::uint64_t gap = id - previousId;
        stats.deltaBytes += uleb128Bytes(gap);
        stats.gapsUnder128 += gap < 128;
        stats.gapsUnder16384 += gap < 16384;
        stats.gapsUnder2097152 += gap < 2097152;
        stats.maximumGap = std::max(stats.maximumGap, gap);
      } else {
        stats.deltaBytes += uleb128Bytes(id);
      }
      havePrevious = true;
      previousId = id;

      Seed seed(static_cast<long long>(id));
      if (seed.length == 8) {
        ++stats.fullLengthSurvivors;
        suffixGroups.push_back(suffixKey(seed));
        for (int position = 0; position < 8; ++position) {
          ++stats.digitHits[position][seed.seed[position]];
        }
      }
    }
    done += count;
  }
  destroyOpeningCharmSoulBatchContext(context);
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - begin).count();

  std::sort(suffixGroups.begin(), suffixGroups.end());
  for (std::size_t index = 0; index < suffixGroups.size();) {
    std::size_t end = index + 1;
    while (end < suffixGroups.size()
           && suffixGroups[end] == suffixGroups[index]) {
      ++end;
    }
    ++stats.occupiedSuffixGroups;
    stats.multiHitSuffixGroups += end - index > 1;
    index = end;
  }

  const double density = static_cast<double>(stats.survivors) / stats.seeds;
  const double fullDomainExpected = density * SEED_DOMAIN_SIZE;
  const double bytesPerCandidate = static_cast<double>(stats.deltaBytes)
      / stats.survivors;
  const double theoreticalProbability =
      (1.0 / 15.0) * (1.0 - std::pow(0.997, 5)) * (1.0 / 5.0);
  const double fullSeedGroups = static_cast<double>(stats.seeds) / 35.0;
  std::cout << std::fixed << std::setprecision(9)
            << "backend="
            << openingCharmSoulBackendName(selectedOpeningCharmSoulBackend())
            << " start=" << startId
            << " seeds=" << stats.seeds
            << " survivors=" << stats.survivors
            << " density=" << density
            << " one_per=" << 1.0 / density
            << " theoretical_density=" << theoreticalProbability
            << " density_ratio=" << density / theoreticalProbability << '\n'
            << "elapsed_seconds=" << seconds
            << " single_thread_Mseeds_per_s="
            << stats.seeds / seconds / 1.0e6 << '\n'
            << "delta_bytes=" << stats.deltaBytes
            << " bytes_per_candidate=" << bytesPerCandidate
            << " projected_candidates_full_domain=" << fullDomainExpected
            << " projected_index_GB="
            << fullDomainExpected * bytesPerCandidate / 1.0e9 << '\n'
            << "gap_lt128=" << stats.gapsUnder128
            << " gap_lt16384=" << stats.gapsUnder16384
            << " gap_lt2097152=" << stats.gapsUnder2097152
            << " maximum_gap=" << stats.maximumGap << '\n'
            << "full_length_survivors=" << stats.fullLengthSurvivors
            << " occupied_7char_suffix_groups="
            << stats.occupiedSuffixGroups
            << " multi_hit_suffix_groups=" << stats.multiHitSuffixGroups
            << " approximate_group_occupancy="
            << stats.occupiedSuffixGroups / fullSeedGroups << '\n';
  printDigitUniformity(stats);
  return 0;
}
