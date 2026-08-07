#include "../src/seed.hpp"
#include "../src/util.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr std::size_t SEED_COUNT = 1u << 18;
constexpr std::size_t DIFFERENTIAL_SEEDS = 1u << 16;
constexpr int REPEATS = 3;
constexpr std::size_t LANES = 8;
constexpr const char *ERRATIC_KEY = "erratic";

enum class GateMode {
  SpecificRankCombined,
  AnyRank,
  SpecificRankAnyOneSuit,
};

struct Criteria {
  GateMode mode = GateMode::SpecificRankCombined;
  int targetRank = 10;
  int minimum = 5;
  const char *name = "specific-rank>=5";
};

struct RunResult {
  std::uint64_t digest = 1469598103934665603ull;
  std::uint64_t hits = 0;
};

inline void mixResult(RunResult &result, bool passed, std::uint64_t index) {
  result.hits += passed ? 1u : 0u;
  result.digest ^= index * 0x9e3779b97f4a7c15ull +
                   (passed ? 0xd1b54a32d192ed03ull
                           : 0x94d049bb133111ebull);
  result.digest *= 1099511628211ull;
}

inline int cardIndexFromBits(std::uint64_t randomBits) {
  double randomPlusOne;
  std::memcpy(&randomPlusOne, &randomBits, sizeof(randomPlusOne));
  const double random = randomPlusOne - 1.0;
  const int index = static_cast<int>(std::floor(random * 52.0));
  return std::clamp(index, 0, 51);
}

inline int nextScalarCard(double &node, double hashedSeed) {
  node = round13(fract(node * 1.72431234 + 2.134453429141));
  return static_cast<int>(
      lua_random_from_seed((node + hashedSeed) * 0.5) * 52.0);
}

inline int nextPositiveFractScalarCard(double &node, double hashedSeed) {
  const double mixed = node * 1.72431234 + 2.134453429141;
  node = round13(mixed - std::floor(mixed));
  return static_cast<int>(
      lua_random_from_seed((node + hashedSeed) * 0.5) * 52.0);
}

struct GateState {
  std::array<std::uint8_t, 13> ranks{};
  std::array<std::array<std::uint8_t, 13>, 4> suitedRanks{};
  int best = 0;
};

inline bool observeCard(GateState &state, const Criteria &criteria,
                        int cardIndex) {
  const int rank = cardIndex % 13;
  switch (criteria.mode) {
  case GateMode::SpecificRankCombined:
    if (rank == criteria.targetRank) {
      state.best = ++state.ranks[rank];
    }
    break;
  case GateMode::AnyRank:
    state.best = std::max<int>(state.best, ++state.ranks[rank]);
    break;
  case GateMode::SpecificRankAnyOneSuit:
    if (rank == criteria.targetRank) {
      const int suit = cardIndex / 13;
      state.best = std::max<int>(
          state.best, ++state.suitedRanks[suit][rank]);
    }
    break;
  }
  return state.best >= criteria.minimum;
}

inline bool scalarGate(Seed &seed, const Criteria &criteria,
                       bool positiveFract) {
  const double hashedSeed = seed.pseudohash(0);
  double node = pseudohash_from(
      ERRATIC_KEY, seed.pseudohash(static_cast<int>(std::strlen(ERRATIC_KEY))));
  GateState state;
  for (int card = 0; card < 52; ++card) {
    const int cardIndex = positiveFract
        ? nextPositiveFractScalarCard(node, hashedSeed)
        : nextScalarCard(node, hashedSeed);
    if (observeCard(state, criteria, cardIndex)) {
      return true;
    }
    if (state.best + (51 - card) < criteria.minimum) {
      return false;
    }
  }
  return false;
}

inline void initLuaState(double seed, std::uint64_t state[4]) {
  double value = seed;
  std::uint64_t repairBits = 0x11090601u;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    const std::uint64_t minimum =
        std::uint64_t{1} << (repairBits & 255u);
    repairBits >>= 8u;
    // This file must be compiled with -ffp-contract=off. A fused multiply-add
    // changes the Balatro/Lua RNG stream.
    value = value * 3.14159265358979323846 + 2.7182818284590452354;
    std::memcpy(&state[recurrence], &value, sizeof(value));
    if (state[recurrence] < minimum) {
      state[recurrence] += minimum;
    }
  }
}

#if defined(__AVX2__)
template <int A, int B, int C, int MASK_SHIFT>
inline __m256i advanceAvx2(__m256i state) {
  const __m256i first = _mm256_srli_epi64(
      _mm256_xor_si256(_mm256_slli_epi64(state, A), state), B);
  const __m256i second = _mm256_slli_epi64(
      _mm256_and_si256(
          state,
          _mm256_set1_epi64x(
              static_cast<long long>(~std::uint64_t{0} << MASK_SHIFT))),
      C);
  return _mm256_xor_si256(first, second);
}

inline void randomBitsAvx2x4(const double *seeds, std::uint64_t *outputs) {
  alignas(32) std::uint64_t initialized[4][4];
  for (int lane = 0; lane < 4; ++lane) {
    initLuaState(seeds[lane], initialized[lane]);
  }
  __m256i z0 = _mm256_set_epi64x(
      static_cast<long long>(initialized[3][0]),
      static_cast<long long>(initialized[2][0]),
      static_cast<long long>(initialized[1][0]),
      static_cast<long long>(initialized[0][0]));
  __m256i z1 = _mm256_set_epi64x(
      static_cast<long long>(initialized[3][1]),
      static_cast<long long>(initialized[2][1]),
      static_cast<long long>(initialized[1][1]),
      static_cast<long long>(initialized[0][1]));
  __m256i z2 = _mm256_set_epi64x(
      static_cast<long long>(initialized[3][2]),
      static_cast<long long>(initialized[2][2]),
      static_cast<long long>(initialized[1][2]),
      static_cast<long long>(initialized[0][2]));
  __m256i z3 = _mm256_set_epi64x(
      static_cast<long long>(initialized[3][3]),
      static_cast<long long>(initialized[2][3]),
      static_cast<long long>(initialized[1][3]),
      static_cast<long long>(initialized[0][3]));
  for (int step = 0; step < 11; ++step) {
    z0 = advanceAvx2<31, 45, 18, 1>(z0);
    z1 = advanceAvx2<19, 30, 28, 6>(z1);
    z2 = advanceAvx2<24, 48, 7, 9>(z2);
    z3 = advanceAvx2<21, 39, 8, 17>(z3);
  }
  const __m256i combined = _mm256_xor_si256(
      _mm256_xor_si256(z0, z1), _mm256_xor_si256(z2, z3));
  const __m256i bits = _mm256_or_si256(
      _mm256_and_si256(
          combined, _mm256_set1_epi64x(4503599627370495ll)),
      _mm256_set1_epi64x(4607182418800017408ll));
  _mm256_storeu_si256(reinterpret_cast<__m256i *>(outputs), bits);
}
#endif

#if defined(__AVX512F__)
template <int A, int B, int C, int MASK_SHIFT>
inline __m512i advanceAvx512(__m512i state) {
  const __m512i first = _mm512_srli_epi64(
      _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
  const __m512i second = _mm512_slli_epi64(
      _mm512_and_si512(
          state,
          _mm512_set1_epi64(
              static_cast<long long>(~std::uint64_t{0} << MASK_SHIFT))),
      C);
  return _mm512_xor_si512(first, second);
}

inline void randomBitsAvx512x8(const double *seeds, std::uint64_t *outputs) {
  alignas(64) std::uint64_t initialized[8][4];
  alignas(64) std::uint64_t transposed[4][8];
  for (int lane = 0; lane < 8; ++lane) {
    initLuaState(seeds[lane], initialized[lane]);
  }
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int lane = 0; lane < 8; ++lane) {
      transposed[recurrence][lane] = initialized[lane][recurrence];
    }
  }
  __m512i z0 = _mm512_load_si512(transposed[0]);
  __m512i z1 = _mm512_load_si512(transposed[1]);
  __m512i z2 = _mm512_load_si512(transposed[2]);
  __m512i z3 = _mm512_load_si512(transposed[3]);
  for (int step = 0; step < 11; ++step) {
    z0 = advanceAvx512<31, 45, 18, 1>(z0);
    z1 = advanceAvx512<19, 30, 28, 6>(z1);
    z2 = advanceAvx512<24, 48, 7, 9>(z2);
    z3 = advanceAvx512<21, 39, 8, 17>(z3);
  }
  const __m512i combined = _mm512_xor_si512(
      _mm512_xor_si512(z0, z1), _mm512_xor_si512(z2, z3));
  const __m512i bits = _mm512_or_si512(
      _mm512_and_si512(
          combined, _mm512_set1_epi64(4503599627370495ll)),
      _mm512_set1_epi64(4607182418800017408ll));
  _mm512_storeu_si512(outputs, bits);
}
#endif

struct PreparedBatch {
  std::array<double, LANES> hashed{};
  std::array<double, LANES> nodes{};
};

PreparedBatch prepareBatch(Seed &seed) {
  PreparedBatch batch;
  for (std::size_t lane = 0; lane < LANES; ++lane) {
    batch.hashed[lane] = seed.pseudohash(0);
    batch.nodes[lane] = pseudohash_from(
        ERRATIC_KEY,
        seed.pseudohash(static_cast<int>(std::strlen(ERRATIC_KEY))));
    seed.next();
  }
  return batch;
}

enum class VectorWidth { Avx2, Avx512 };

void advanceBatchNodes(PreparedBatch &batch, VectorWidth width,
                       bool positiveFract) {
  if (!positiveFract) {
    for (std::size_t lane = 0; lane < LANES; ++lane) {
      batch.nodes[lane] = round13(fract(
          batch.nodes[lane] * 1.72431234 + 2.134453429141));
    }
    return;
  }

  alignas(64) double fractional[LANES];
#if defined(__AVX512F__)
  if (width == VectorWidth::Avx512) {
    const __m512d nodes = _mm512_loadu_pd(batch.nodes.data());
    const __m512d mixed = _mm512_add_pd(
        _mm512_mul_pd(nodes, _mm512_set1_pd(1.72431234)),
        _mm512_set1_pd(2.134453429141));
    _mm512_store_pd(
        fractional, _mm512_sub_pd(mixed, _mm512_floor_pd(mixed)));
  } else
#endif
  {
#if defined(__AVX2__)
    for (std::size_t first = 0; first < LANES; first += 4) {
      const __m256d nodes = _mm256_loadu_pd(batch.nodes.data() + first);
      const __m256d mixed = _mm256_add_pd(
          _mm256_mul_pd(nodes, _mm256_set1_pd(1.72431234)),
          _mm256_set1_pd(2.134453429141));
      _mm256_store_pd(
          fractional + first,
          _mm256_sub_pd(mixed, _mm256_floor_pd(mixed)));
    }
#else
    for (std::size_t lane = 0; lane < LANES; ++lane) {
      const double mixed =
          batch.nodes[lane] * 1.72431234 + 2.134453429141;
      fractional[lane] = mixed - std::floor(mixed);
    }
#endif
  }
  for (std::size_t lane = 0; lane < LANES; ++lane) {
    batch.nodes[lane] = round13(fractional[lane]);
  }
}

std::uint8_t vectorGateBatch(PreparedBatch &batch, const Criteria &criteria,
                             VectorWidth width,
                             bool positiveFract,
                             std::uint8_t cardsOut[LANES][52] = nullptr) {
  std::array<GateState, LANES> states{};
  std::array<double, LANES> randomSeeds{};
  alignas(64) std::uint64_t randomBits[LANES];
  std::uint8_t unresolved = 0xffu;
  std::uint8_t passed = 0;
  const bool traceAllCards = cardsOut != nullptr;

  for (int card = 0;
       card < 52 && (traceAllCards || unresolved != 0); ++card) {
    advanceBatchNodes(batch, width, positiveFract);
    for (std::size_t lane = 0; lane < LANES; ++lane) {
      randomSeeds[lane] =
          (batch.nodes[lane] + batch.hashed[lane]) * 0.5;
    }

#if defined(__AVX512F__)
    if (width == VectorWidth::Avx512) {
      randomBitsAvx512x8(randomSeeds.data(), randomBits);
    } else
#endif
    {
#if defined(__AVX2__)
      randomBitsAvx2x4(randomSeeds.data(), randomBits);
      randomBitsAvx2x4(randomSeeds.data() + 4, randomBits + 4);
#else
      for (std::size_t lane = 0; lane < LANES; ++lane) {
        double value = lua_random_from_seed(randomSeeds[lane]) + 1.0;
        std::memcpy(&randomBits[lane], &value, sizeof(value));
      }
#endif
    }

    for (std::size_t lane = 0; lane < LANES; ++lane) {
      const int index = cardIndexFromBits(randomBits[lane]);
      if (cardsOut != nullptr) {
        cardsOut[lane][card] = static_cast<std::uint8_t>(index);
      }
      if (traceAllCards) {
        continue;
      }
      const std::uint8_t bit = static_cast<std::uint8_t>(1u << lane);
      if ((unresolved & bit) == 0) {
        continue;
      }
      if (observeCard(states[lane], criteria, index)) {
        passed |= bit;
        unresolved &= static_cast<std::uint8_t>(~bit);
      } else if (states[lane].best + (51 - card) < criteria.minimum) {
        unresolved &= static_cast<std::uint8_t>(~bit);
      }
    }
  }
  return passed;
}

RunResult runScalar(long long startId, std::size_t count,
                    const Criteria &criteria, bool positiveFract) {
  Seed seed(startId);
  RunResult result;
  for (std::size_t index = 0; index < count; ++index) {
    mixResult(result, scalarGate(seed, criteria, positiveFract), index);
    seed.next();
  }
  return result;
}

RunResult runVector(long long startId, std::size_t count,
                    const Criteria &criteria, VectorWidth width,
                    bool positiveFract) {
  Seed seed(startId);
  RunResult result;
  for (std::size_t index = 0; index < count; index += LANES) {
    PreparedBatch batch = prepareBatch(seed);
    const std::uint8_t passed = vectorGateBatch(
        batch, criteria, width, positiveFract);
    for (std::size_t lane = 0; lane < LANES; ++lane) {
      mixResult(result, (passed & (1u << lane)) != 0, index + lane);
    }
  }
  return result;
}

template <typename Function>
double benchmark(Function function, RunResult &result) {
  double best = std::numeric_limits<double>::infinity();
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    const auto started = std::chrono::steady_clock::now();
    const RunResult current = function();
    const double seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - started).count();
    best = std::min(best, seconds);
    result = current;
  }
  return best;
}

bool differentialCheck(long long startId) {
  Seed vectorSeed(startId);
  constexpr Criteria TRACE_CRITERIA{
      GateMode::SpecificRankCombined, 10, 53, "trace"};
  for (std::size_t offset = 0; offset < DIFFERENTIAL_SEEDS;
       offset += LANES) {
    PreparedBatch batch = prepareBatch(vectorSeed);
    std::uint8_t vectorCards[LANES][52]{};
#if defined(__AVX512F__)
    vectorGateBatch(
        batch, TRACE_CRITERIA, VectorWidth::Avx512, true, vectorCards);
#else
    vectorGateBatch(
        batch, TRACE_CRITERIA, VectorWidth::Avx2, true, vectorCards);
#endif
    for (std::size_t lane = 0; lane < LANES; ++lane) {
      Seed scalarSeed(startId + static_cast<long long>(offset + lane));
      const double hashedSeed = scalarSeed.pseudohash(0);
      double node = pseudohash_from(
          ERRATIC_KEY,
          scalarSeed.pseudohash(static_cast<int>(std::strlen(ERRATIC_KEY))));
      for (int card = 0; card < 52; ++card) {
        const int scalarCard = nextScalarCard(node, hashedSeed);
        if (vectorCards[lane][card] != scalarCard) {
          std::cerr << "Differential mismatch seed_offset=" << offset + lane
                    << " card=" << card << " scalar=" << scalarCard
                    << " vector=" << static_cast<int>(vectorCards[lane][card])
                    << '\n';
          return false;
        }
      }
    }
  }
  return true;
}

void printResult(const char *implementation, const Criteria &criteria,
                 double seconds, const RunResult &result,
                 double scalarSeconds) {
  std::cout << std::left << std::setw(17) << implementation << " "
            << std::setw(25) << criteria.name << " seconds=" << std::fixed
            << std::setprecision(6) << seconds << " Mseed/s="
            << std::setprecision(3)
            << static_cast<double>(SEED_COUNT) / seconds / 1.0e6
            << " speedup=" << std::setprecision(3)
            << scalarSeconds / seconds << "x hits=" << result.hits
            << " digest=" << result.digest << '\n';
}

enum class ParallelImplementation {
  ScalarPositive,
  Avx2Positive,
  Avx512Positive,
};

struct ParallelMeasurement {
  double seconds = 0.0;
  std::uint64_t hits = 0;
  std::uint64_t digest = 0;
};

ParallelMeasurement runParallel(
    int threadCount, long long startId, const Criteria &criteria,
    ParallelImplementation implementation) {
  std::vector<RunResult> results(static_cast<std::size_t>(threadCount));
  std::atomic<int> ready{0};
  std::atomic<bool> go{false};
  std::vector<std::thread> workers;
  workers.reserve(static_cast<std::size_t>(threadCount));
  for (int worker = 0; worker < threadCount; ++worker) {
    workers.emplace_back([&, worker]() {
      ready.fetch_add(1, std::memory_order_release);
      while (!go.load(std::memory_order_acquire)) {
        std::this_thread::yield();
      }
      const long long workerStart =
          startId + static_cast<long long>(worker) * SEED_COUNT;
      switch (implementation) {
      case ParallelImplementation::ScalarPositive:
        results[worker] =
            runScalar(workerStart, SEED_COUNT, criteria, true);
        break;
      case ParallelImplementation::Avx2Positive:
        results[worker] = runVector(
            workerStart, SEED_COUNT, criteria, VectorWidth::Avx2, true);
        break;
      case ParallelImplementation::Avx512Positive:
#if defined(__AVX512F__)
        results[worker] = runVector(
            workerStart, SEED_COUNT, criteria, VectorWidth::Avx512, true);
#else
        results[worker] = runVector(
            workerStart, SEED_COUNT, criteria, VectorWidth::Avx2, true);
#endif
        break;
      }
    });
  }
  while (ready.load(std::memory_order_acquire) != threadCount) {
    std::this_thread::yield();
  }
  const auto started = std::chrono::steady_clock::now();
  go.store(true, std::memory_order_release);
  for (std::thread &worker : workers) {
    worker.join();
  }
  ParallelMeasurement measurement;
  measurement.seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  for (int worker = 0; worker < threadCount; ++worker) {
    measurement.hits += results[worker].hits;
    measurement.digest ^=
        results[worker].digest
        + static_cast<std::uint64_t>(worker) * 0x9e3779b97f4a7c15ull;
  }
  return measurement;
}

void printParallel(const char *implementation, int threadCount,
                   const ParallelMeasurement &measurement,
                   double scalarSeconds) {
  const double seeds =
      static_cast<double>(SEED_COUNT) * static_cast<double>(threadCount);
  std::cout << "parallel " << std::left << std::setw(16) << implementation
            << " threads=" << std::setw(2) << threadCount << " seconds="
            << std::fixed << std::setprecision(6) << measurement.seconds
            << " Mseed/s=" << std::setprecision(3)
            << seeds / measurement.seconds / 1.0e6 << " speedup="
            << scalarSeconds / measurement.seconds << "x hits="
            << measurement.hits << " digest=" << measurement.digest << '\n';
}

} // namespace

int main() {
#if !defined(__AVX2__)
  std::cout << "Built without AVX2; SIMD measurements unavailable.\n";
  return 0;
#else
  constexpr long long START_ID = 9182736451ll;
  if (!differentialCheck(START_ID)) {
    return 1;
  }
  std::cout << "Differential check: " << DIFFERENTIAL_SEEDS
            << " seeds x 52 cards matched exactly\n";

  constexpr std::array<Criteria, 5> CRITERIA = {{
      {GateMode::SpecificRankCombined, 10, 5, "specific rank >= 5"},
      {GateMode::SpecificRankCombined, 10, 8, "specific rank >= 8"},
      {GateMode::AnyRank, 0, 8, "any rank >= 8"},
      {GateMode::AnyRank, 0, 10, "any rank >= 10"},
      {GateMode::SpecificRankAnyOneSuit, 10, 3,
       "specific rank/suit >= 3"},
  }};

  for (const Criteria &criteria : CRITERIA) {
    RunResult scalar;
    const double scalarSeconds = benchmark(
        [&]() { return runScalar(START_ID, SEED_COUNT, criteria, false); },
        scalar);
    printResult("scalar", criteria, scalarSeconds, scalar, scalarSeconds);

    RunResult scalarPositive;
    const double scalarPositiveSeconds = benchmark(
        [&]() { return runScalar(START_ID, SEED_COUNT, criteria, true); },
        scalarPositive);
    if (scalarPositive.digest != scalar.digest
        || scalarPositive.hits != scalar.hits) {
      std::cerr << "Positive-fract scalar mismatch for " << criteria.name
                << '\n';
      return 1;
    }
    printResult(
        "scalar-positive", criteria, scalarPositiveSeconds,
        scalarPositive, scalarSeconds);

    RunResult avx2;
    const double avx2Seconds = benchmark(
        [&]() {
          return runVector(
              START_ID, SEED_COUNT, criteria, VectorWidth::Avx2, false);
        },
        avx2);
    if (avx2.digest != scalar.digest || avx2.hits != scalar.hits) {
      std::cerr << "AVX2 gate result mismatch for " << criteria.name << '\n';
      return 1;
    }
    printResult("avx2-2x4", criteria, avx2Seconds, avx2, scalarSeconds);

    RunResult avx2Positive;
    const double avx2PositiveSeconds = benchmark(
        [&]() {
          return runVector(
              START_ID, SEED_COUNT, criteria, VectorWidth::Avx2, true);
        },
        avx2Positive);
    if (avx2Positive.digest != scalar.digest
        || avx2Positive.hits != scalar.hits) {
      std::cerr << "AVX2 positive-fract gate mismatch for "
                << criteria.name << '\n';
      return 1;
    }
    printResult(
        "avx2-positive", criteria, avx2PositiveSeconds,
        avx2Positive, scalarSeconds);

#if defined(__AVX512F__)
    RunResult avx512;
    const double avx512Seconds = benchmark(
        [&]() {
          return runVector(
              START_ID, SEED_COUNT, criteria, VectorWidth::Avx512, false);
        },
        avx512);
    if (avx512.digest != scalar.digest || avx512.hits != scalar.hits) {
      std::cerr << "AVX-512 gate result mismatch for " << criteria.name
                << '\n';
      return 1;
    }
    printResult("avx512-8", criteria, avx512Seconds, avx512, scalarSeconds);

    RunResult avx512Positive;
    const double avx512PositiveSeconds = benchmark(
        [&]() {
          return runVector(
              START_ID, SEED_COUNT, criteria, VectorWidth::Avx512, true);
        },
        avx512Positive);
    if (avx512Positive.digest != scalar.digest
        || avx512Positive.hits != scalar.hits) {
      std::cerr << "AVX-512 positive-fract gate mismatch for "
                << criteria.name << '\n';
      return 1;
    }
    printResult(
        "avx512-positive", criteria, avx512PositiveSeconds,
        avx512Positive, scalarSeconds);
#endif
  }

  // A modest multi-thread check catches AVX-frequency or memory/cache effects
  // without saturating all logical CPUs on the user's machine.
  constexpr Criteria PARALLEL_CRITERIA{
      GateMode::SpecificRankCombined, 10, 8, "parallel"};
  for (int threadCount : {1, 4, 8}) {
    const ParallelMeasurement scalar = runParallel(
        threadCount, START_ID, PARALLEL_CRITERIA,
        ParallelImplementation::ScalarPositive);
    printParallel("scalar-positive", threadCount, scalar, scalar.seconds);

    const ParallelMeasurement avx2 = runParallel(
        threadCount, START_ID, PARALLEL_CRITERIA,
        ParallelImplementation::Avx2Positive);
    if (avx2.hits != scalar.hits || avx2.digest != scalar.digest) {
      std::cerr << "Parallel AVX2 mismatch at " << threadCount
                << " threads\n";
      return 1;
    }
    printParallel("avx2-positive", threadCount, avx2, scalar.seconds);

#if defined(__AVX512F__)
    const ParallelMeasurement avx512 = runParallel(
        threadCount, START_ID, PARALLEL_CRITERIA,
        ParallelImplementation::Avx512Positive);
    if (avx512.hits != scalar.hits || avx512.digest != scalar.digest) {
      std::cerr << "Parallel AVX-512 mismatch at " << threadCount
                << " threads\n";
      return 1;
    }
    printParallel("avx512-positive", threadCount, avx512, scalar.seconds);
#endif
  }
  return 0;
#endif
}
