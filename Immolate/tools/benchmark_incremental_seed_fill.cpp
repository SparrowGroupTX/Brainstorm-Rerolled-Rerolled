#include "../src/opening_batch_vector.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <vector>

namespace {

using BrainstormOpeningBatchDetail::ChunkSeeds;

struct IncrementalPackedSeed {
  std::array<std::uint8_t, 8> digits{};
  std::uint64_t packedCharacters = 0;
  int length = 0;

  explicit IncrementalPackedSeed(long long rawId) {
    const std::uint64_t initialCharacter = static_cast<unsigned char>(
        seedChars[0]);
    for (int position = 0; position < 8; ++position) {
      packedCharacters |= initialCharacter << (position * 8);
    }

    long long id = normalizeSeedId(rawId);
    for (int position = 0; position < 8; ++position) {
      if (id <= 0) {
        break;
      }
      ++length;
      const std::uint8_t digit = static_cast<std::uint8_t>(
          (id - 1) / idCoeff[static_cast<std::size_t>(position)]);
      digits[static_cast<std::size_t>(position)] = digit;
      setPackedCharacter(position, digit);
      id -= 1 + static_cast<long long>(digit)
          * idCoeff[static_cast<std::size_t>(position)];
    }
  }

  void setPackedCharacter(int position, std::uint8_t digit) {
    const int shift = position * 8;
    const std::uint64_t mask = std::uint64_t{0xff} << shift;
    packedCharacters = (packedCharacters & ~mask)
        | (static_cast<std::uint64_t>(static_cast<unsigned char>(
               seedChars[digit]))
           << shift);
  }

  void next() {
    if (length < 8) {
      digits[static_cast<std::size_t>(length++)] = 0;
      return;
    }
    for (int position = 7; position >= 0; --position) {
      std::uint8_t& digit = digits[static_cast<std::size_t>(position)];
      if (digit == 34) {
        digit = 0;
        setPackedCharacter(position, digit);
        --length;
      } else {
        ++digit;
        setPackedCharacter(position, digit);
        break;
      }
    }
  }
};

#if defined(__GNUC__)
__attribute__((noinline))
#endif
void fillIncremental(ChunkSeeds& chunk, long long startSeedId,
                     std::size_t count) {
  IncrementalPackedSeed seed(startSeedId);
  for (std::size_t index = 0; index < count; ++index) {
    chunk.lengths[index] = static_cast<std::uint8_t>(seed.length);
    chunk.packedCharacters[index] = seed.packedCharacters;
    seed.next();
  }
}

bool verifyRange(long long startSeedId, std::size_t count) {
  ChunkSeeds baseline;
  ChunkSeeds candidate;
  baseline.resize(count);
  candidate.resize(count);
  BrainstormOpeningBatchDetail::fillChunk(
      baseline, startSeedId, count);
  fillIncremental(candidate, startSeedId, count);
  for (std::size_t index = 0; index < count; ++index) {
    if (baseline.lengths[index] != candidate.lengths[index]
        || baseline.packedCharacters[index]
            != candidate.packedCharacters[index]) {
      std::cerr << "mismatch start=" << startSeedId
                << " offset=" << index << '\n';
      return false;
    }
  }
  return true;
}

template <class Fill>
double runBenchmark(Fill fill, std::uint64_t& checksum) {
  constexpr std::size_t chunkSize = 4096;
  constexpr int chunks = 8192;
  ChunkSeeds chunk;
  chunk.resize(chunkSize);
  long long start = 1000000000000ll;
  const auto began = std::chrono::steady_clock::now();
  for (int iteration = 0; iteration < chunks; ++iteration) {
    fill(chunk, start, chunkSize);
    checksum ^= chunk.packedCharacters[
        static_cast<std::size_t>(iteration) & (chunkSize - 1)];
    checksum += chunk.lengths[
        (static_cast<std::size_t>(iteration) * 17) & (chunkSize - 1)];
    start = normalizeSeedId(start + static_cast<long long>(chunkSize));
  }
  return std::chrono::duration<double>(
      std::chrono::steady_clock::now() - began).count();
}

double median(std::vector<double> values) {
  std::sort(values.begin(), values.end());
  return values[values.size() / 2];
}

} // namespace

int main() {
  const std::array<long long, 6> starts = {
      0,
      1,
      1000000000000ll,
      idCoeff[0] - 32768,
      SEED_DOMAIN_SIZE - 65536,
      SEED_DOMAIN_SIZE - 1,
  };
  for (long long start : starts) {
    if (!verifyRange(start, 131072)) {
      return 1;
    }
  }
  std::cout << "verification=exact seeds="
            << starts.size() * 131072 << '\n';

  std::vector<double> baselineTimes;
  std::vector<double> candidateTimes;
  std::uint64_t checksum = 0;
  for (int pair = 0; pair < 7; ++pair) {
    if ((pair & 1) == 0) {
      baselineTimes.push_back(runBenchmark(
          [](ChunkSeeds& chunk, long long start, std::size_t count) {
            BrainstormOpeningBatchDetail::fillChunk(
                chunk, start, count);
          }, checksum));
      candidateTimes.push_back(runBenchmark(
          fillIncremental, checksum));
    } else {
      candidateTimes.push_back(runBenchmark(
          fillIncremental, checksum));
      baselineTimes.push_back(runBenchmark(
          [](ChunkSeeds& chunk, long long start, std::size_t count) {
            BrainstormOpeningBatchDetail::fillChunk(
                chunk, start, count);
          }, checksum));
    }
  }

  const double baseline = median(baselineTimes);
  const double candidate = median(candidateTimes);
  constexpr double evaluations = 4096.0 * 8192.0;
  std::cout << std::fixed << std::setprecision(6)
            << "baseline_seconds=" << baseline
            << " baseline_Mseeds_per_s="
            << evaluations / baseline / 1.0e6 << '\n'
            << "candidate_seconds=" << candidate
            << " candidate_Mseeds_per_s="
            << evaluations / candidate / 1.0e6 << '\n'
            << "speedup=" << baseline / candidate << "x\n"
            << "checksum=" << checksum << '\n';
  return 0;
}
