// Standalone diagnostic for batching the exact opening Charm/Soul/Perkeo
// necessary gate across seeds. This is intentionally not part of the build.
//
// Suggested GCC invocation (the FP flags are correctness requirements):
//   g++ -std=c++20 -O3 -march=native -ffp-contract=off \
//     benchmark_opening_gate_batch.cpp ../src/seed.cpp ../src/util.cpp \
//     -o benchmark_opening_gate_batch.exe
//
// Do not use -ffast-math: Balatro seed results depend on strict FP64 rounding.

#include "../src/seed.hpp"
#include "../src/util.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <limits>
#include <string>
#include <string_view>
#include <vector>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace {

#if defined(__GNUC__) || defined(__clang__)
#define BENCH_NOINLINE __attribute__((noinline))
#define BENCH_ALWAYS_INLINE inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#define BENCH_NOINLINE __declspec(noinline)
#define BENCH_ALWAYS_INLINE __forceinline
#else
#define BENCH_NOINLINE
#define BENCH_ALWAYS_INLINE inline
#endif

constexpr std::uint64_t ALL_BITS = ~std::uint64_t{0};
constexpr std::uint64_t RANDOM_MANTISSA = 4503599627370495ull;
constexpr std::uint64_t ONE_EXPONENT = 4607182418800017408ull;
constexpr double LUA_PI = 3.14159265358979323846;
constexpr double LUA_E = 2.7182818284590452354;
constexpr double HASH_A = 1.1239285023;
constexpr double HASH_PI = 3.141592653589793116;
constexpr double NODE_MUL = 1.72431234;
constexpr double NODE_ADD = 2.134453429141;
constexpr double SOUL_THRESHOLD = 0.997;
constexpr std::string_view TAG_KEY = "Tag1";
constexpr std::string_view SOUL_TAROT_KEY = "soul_Tarot1";
constexpr std::string_view LEGENDARY_KEY = "Joker4";

constexpr std::size_t SAMPLE_COUNT = 1u << 20;
constexpr std::size_t VERIFY_COUNT = 1u << 20;
constexpr int REPEATS = 3;
constexpr long long START_SEED_ID = 1000000000000ll;

inline std::uint64_t stepWord(std::uint64_t z, int recurrence) {
  switch (recurrence) {
  case 0:
    return (((z << 31u) ^ z) >> 45u) ^
           ((z & (ALL_BITS << 1u)) << 18u);
  case 1:
    return (((z << 19u) ^ z) >> 30u) ^
           ((z & (ALL_BITS << 6u)) << 28u);
  case 2:
    return (((z << 24u) ^ z) >> 48u) ^
           ((z & (ALL_BITS << 9u)) << 7u);
  default:
    return (((z << 21u) ^ z) >> 39u) ^
           ((z & (ALL_BITS << 17u)) << 8u);
  }
}

inline std::uint64_t jump11Word(std::uint64_t value, int recurrence) {
  for (int step = 0; step < 11; ++step) {
    value = stepWord(value, recurrence);
  }
  return value;
}

using ByteTable11 =
    std::array<std::array<std::array<std::uint64_t, 256>, 8>, 4>;

ByteTable11 buildByteTable11() {
  ByteTable11 result{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int byte = 0; byte < 8; ++byte) {
      for (int value = 0; value < 256; ++value) {
        result[recurrence][byte][value] = jump11Word(
            static_cast<std::uint64_t>(value) << (byte * 8), recurrence);
      }
    }
  }
  return result;
}

inline std::uint64_t tableJump11(std::uint64_t value, int recurrence,
                                 const ByteTable11 &table) {
  std::uint64_t result = 0;
  for (int byte = 0; byte < 8; ++byte) {
    result ^= table[recurrence][byte][value & 0xffu];
    value >>= 8u;
  }
  return result;
}

inline void initRandom(double seed, std::uint64_t state[4]) {
  double value = seed;
  std::uint64_t repair = 0x11090601;
  for (int i = 0; i < 4; ++i) {
    const std::uint64_t minimum = std::uint64_t{1} << (repair & 255u);
    repair >>= 8u;
    value = value * LUA_PI + LUA_E;
    std::uint64_t bits = std::bit_cast<std::uint64_t>(value);
    if (bits < minimum) {
      bits += minimum;
    }
    state[i] = bits;
  }
}

BENCH_NOINLINE double tableRandom(double seed, const ByteTable11 &table) {
  std::uint64_t state[4];
  initRandom(seed, state);
  std::uint64_t bits = 0;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    bits ^= tableJump11(state[recurrence], recurrence, table);
  }
  bits = (bits & RANDOM_MANTISSA) | ONE_EXPONENT;
  return std::bit_cast<double>(bits) - 1.0;
}

using RandomFunction = double (*)(double, const ByteTable11 *);

BENCH_NOINLINE double baselineRandomAdapter(double seed,
                                             const ByteTable11 *) {
  return lua_random_from_seed(seed);
}

BENCH_NOINLINE double tableRandomAdapter(double seed,
                                          const ByteTable11 *table) {
  return tableRandom(seed, *table);
}

bool isLockedAnteOneTagIndex(int index) {
  // TAGS indices for Negative, Standard, Meteor, Buffoon, Handy, Garbage,
  // Ethereal, Top-up, and Orbital. Charm is index 10.
  switch (index) {
  case 2:
  case 9:
  case 11:
  case 12:
  case 13:
  case 14:
  case 15:
  case 20:
  case 22:
    return true;
  default:
    return false;
  }
}

double advanceNodeScalar(double value) {
  return round13(fract(value * NODE_MUL + NODE_ADD));
}

double freshNodeScalar(Seed &seed, double hashedSeed,
                       std::string_view key) {
  const std::string owned(key);
  double value = pseudohash_from(
      owned, seed.pseudohash(static_cast<int>(owned.size())));
  value = advanceNodeScalar(value);
  return (value + hashedSeed) * 0.5;
}

bool scalarOpeningGate(Seed &seed, RandomFunction random,
                       const ByteTable11 *table) {
  const double hashedSeed = seed.pseudohash(0);

  int resample = 1;
  while (true) {
    std::string key;
    if (resample == 1) {
      key.assign(TAG_KEY);
    } else {
      key.assign(TAG_KEY);
      key += "_resample";
      key += std::to_string(resample);
    }
    const int tag = static_cast<int>(
        random(freshNodeScalar(seed, hashedSeed, key), table) * 24.0);
    if (!isLockedAnteOneTagIndex(tag) || resample >= 1000) {
      if (tag != 10) {
        return false;
      }
      break;
    }
    ++resample;
  }

  const std::string soulKey(SOUL_TAROT_KEY);
  double soulState = pseudohash_from(
      soulKey, seed.pseudohash(static_cast<int>(soulKey.size())));
  bool foundSoul = false;
  for (int card = 0; card < 5; ++card) {
    soulState = advanceNodeScalar(soulState);
    if (random((soulState + hashedSeed) * 0.5, table) >
        SOUL_THRESHOLD) {
      foundSoul = true;
      break;
    }
  }
  if (!foundSoul) {
    return false;
  }

  const int legendary = static_cast<int>(
      random(freshNodeScalar(seed, hashedSeed, LEGENDARY_KEY), table) * 5.0);
  return legendary == 4;
}

struct CompactSeed {
  std::array<std::uint8_t, 8> digits{};
  int length = 0;

  explicit CompactSeed(long long id) {
    for (int i = 0; i < 8; ++i) {
      if (id > 0) {
        ++length;
        digits[i] = static_cast<std::uint8_t>((id - 1) / idCoeff[i]);
        id -= 1 + static_cast<long long>(digits[i]) * idCoeff[i];
      }
    }
  }

  void next() {
    if (length < 8) {
      digits[length++] = 0;
      return;
    }
    for (int i = 7; i >= 0; --i) {
      if (digits[i] == 34) {
        digits[i] = 0;
        --length;
      } else {
        ++digits[i];
        break;
      }
    }
  }
};

double compactPseudohash(const CompactSeed &seed, int prefixLength) {
  double value = 1.0;
  for (int i = 0; i < seed.length; ++i) {
    value = pseudostep(
        seedChars[seed.digits[i]], prefixLength + seed.length - i, value);
  }
  return value;
}

struct ChunkSeeds {
  std::array<std::vector<double>, 8> chars;
  std::vector<double> lengths;
  std::vector<double> hashedSeed;
  std::vector<int> identity;

  explicit ChunkSeeds(std::size_t capacity) {
    for (auto &column : chars) {
      column.resize(capacity);
    }
    lengths.resize(capacity);
    hashedSeed.resize(capacity);
    identity.resize(capacity);
  }
};

template <class Backend>
BENCH_ALWAYS_INLINE typename Backend::DoubleVector vectorFractPositive(
    typename Backend::DoubleVector value) {
  return Backend::sub(value, Backend::floor(value));
}

template <class Backend>
BENCH_ALWAYS_INLINE typename Backend::DoubleVector vectorSeedPseudohash(
    const ChunkSeeds &seeds, const int *indices, int valid,
    int prefixLength) {
  using D = typename Backend::DoubleVector;
  const auto gatherIndices = Backend::indices(indices, valid);
  const D lengths = Backend::gather(seeds.lengths.data(), gatherIndices);
  D value = Backend::set1(1.0);
  for (int position = 0; position < 8; ++position) {
    const D character = Backend::gather(
        seeds.chars[position].data(), gatherIndices);
    D next = Backend::div(Backend::set1(HASH_A), value);
    next = Backend::mul(next, character);
    next = Backend::mul(next, Backend::set1(HASH_PI));
    const D hashPosition = Backend::add(
        Backend::set1(static_cast<double>(prefixLength - position)), lengths);
    next = Backend::add(next, Backend::mul(
                                  Backend::set1(HASH_PI), hashPosition));
    const D advanced = vectorFractPositive<Backend>(next);
    value = Backend::select(
        Backend::greater(lengths, Backend::set1(static_cast<double>(position))),
        value, advanced);
  }
  return value;
}

template <class Backend>
BENCH_ALWAYS_INLINE typename Backend::DoubleVector vectorPseudohashFrom(
    std::string_view key, typename Backend::DoubleVector value) {
  for (std::size_t index = key.size(); index > 0; --index) {
    auto next = Backend::div(Backend::set1(HASH_A), value);
    next = Backend::mul(
        next, Backend::set1(static_cast<unsigned char>(key[index - 1])));
    next = Backend::mul(next, Backend::set1(HASH_PI));
    next = Backend::add(next, Backend::set1(HASH_PI * index));
    value = vectorFractPositive<Backend>(next);
  }
  return value;
}

template <class Backend>
BENCH_ALWAYS_INLINE typename Backend::DoubleVector vectorAdvanceNode(
    typename Backend::DoubleVector value) {
  alignas(64) double lanes[Backend::LANES];
  value = Backend::add(
      Backend::mul(value, Backend::set1(NODE_MUL)),
      Backend::set1(NODE_ADD));
  value = vectorFractPositive<Backend>(value);
  Backend::store(lanes, value);
  for (int lane = 0; lane < Backend::LANES; ++lane) {
    lanes[lane] = round13(lanes[lane]);
  }
  return Backend::load(lanes);
}

template <class Backend>
BENCH_ALWAYS_INLINE typename Backend::DoubleVector vectorRandom(
    typename Backend::DoubleVector seed) {
  using D = typename Backend::DoubleVector;
  using I = typename Backend::IntegerVector;
  D value = seed;
  std::array<I, 4> state;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    value = Backend::add(
        Backend::mul(value, Backend::set1(LUA_PI)), Backend::set1(LUA_E));
    state[recurrence] = Backend::asInteger(value);
    // Opening-gate node seeds are nonnegative and the resulting normal
    // doubles have bit patterns far above Lua's tiny repair minima.
  }
  for (int step = 0; step < 11; ++step) {
    state[0] = Backend::template advance<31, 45, 18, 1>(state[0]);
    state[1] = Backend::template advance<19, 30, 28, 6>(state[1]);
    state[2] = Backend::template advance<24, 48, 7, 9>(state[2]);
    state[3] = Backend::template advance<21, 39, 8, 17>(state[3]);
  }
  I bits = Backend::bitOr(
      Backend::bitAnd(
          Backend::bitXor(Backend::bitXor(state[0], state[1]),
                          Backend::bitXor(state[2], state[3])),
          Backend::set1Integer(RANDOM_MANTISSA)),
      Backend::set1Integer(ONE_EXPONENT));
  return Backend::sub(Backend::asDouble(bits), Backend::set1(1.0));
}

#if defined(__AVX2__)
struct Avx2Backend {
  static constexpr int LANES = 4;
  using DoubleVector = __m256d;
  using IntegerVector = __m256i;
  using GatherIndices = std::array<int, LANES>;
  using Mask = __m256d;

  static DoubleVector set1(double x) { return _mm256_set1_pd(x); }
  static IntegerVector set1Integer(std::uint64_t x) {
    return _mm256_set1_epi64x(static_cast<long long>(x));
  }
  static DoubleVector add(DoubleVector a, DoubleVector b) {
    return _mm256_add_pd(a, b);
  }
  static DoubleVector sub(DoubleVector a, DoubleVector b) {
    return _mm256_sub_pd(a, b);
  }
  static DoubleVector mul(DoubleVector a, DoubleVector b) {
    return _mm256_mul_pd(a, b);
  }
  static DoubleVector div(DoubleVector a, DoubleVector b) {
    return _mm256_div_pd(a, b);
  }
  static DoubleVector floor(DoubleVector a) { return _mm256_floor_pd(a); }
  static Mask greater(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_GT_OQ);
  }
  static DoubleVector select(Mask mask, DoubleVector whenFalse,
                             DoubleVector whenTrue) {
    return _mm256_blendv_pd(whenFalse, whenTrue, mask);
  }
  static DoubleVector load(const double *a) { return _mm256_loadu_pd(a); }
  static void store(double *out, DoubleVector a) {
    _mm256_storeu_pd(out, a);
  }
  static IntegerVector asInteger(DoubleVector a) {
    return _mm256_castpd_si256(a);
  }
  static DoubleVector asDouble(IntegerVector a) {
    return _mm256_castsi256_pd(a);
  }
  static IntegerVector bitAnd(IntegerVector a, IntegerVector b) {
    return _mm256_and_si256(a, b);
  }
  static IntegerVector bitOr(IntegerVector a, IntegerVector b) {
    return _mm256_or_si256(a, b);
  }
  static IntegerVector bitXor(IntegerVector a, IntegerVector b) {
    return _mm256_xor_si256(a, b);
  }
  static GatherIndices indices(const int *input, int valid) {
    const int last = input[valid - 1];
    return {input[0], valid > 1 ? input[1] : last,
            valid > 2 ? input[2] : last, valid > 3 ? input[3] : last};
  }
  static DoubleVector gather(const double *base, GatherIndices indices) {
    return _mm256_set_pd(base[indices[3]], base[indices[2]],
                         base[indices[1]], base[indices[0]]);
  }
  template <int A, int B, int C, int MASK_SHIFT>
  static IntegerVector advance(IntegerVector state) {
    const IntegerVector first = _mm256_srli_epi64(
        _mm256_xor_si256(_mm256_slli_epi64(state, A), state), B);
    const IntegerVector second = _mm256_slli_epi64(
        _mm256_and_si256(
            state, _mm256_set1_epi64x(
                       static_cast<long long>(ALL_BITS << MASK_SHIFT))),
        C);
    return _mm256_xor_si256(first, second);
  }
};
#endif

#if defined(__AVX512F__)
struct Avx512Backend {
  static constexpr int LANES = 8;
  using DoubleVector = __m512d;
  using IntegerVector = __m512i;
  using GatherIndices = std::array<int, LANES>;
  using Mask = __mmask8;

  static DoubleVector set1(double x) { return _mm512_set1_pd(x); }
  static IntegerVector set1Integer(std::uint64_t x) {
    return _mm512_set1_epi64(static_cast<long long>(x));
  }
  static DoubleVector add(DoubleVector a, DoubleVector b) {
    return _mm512_add_pd(a, b);
  }
  static DoubleVector sub(DoubleVector a, DoubleVector b) {
    return _mm512_sub_pd(a, b);
  }
  static DoubleVector mul(DoubleVector a, DoubleVector b) {
    return _mm512_mul_pd(a, b);
  }
  static DoubleVector div(DoubleVector a, DoubleVector b) {
    return _mm512_div_pd(a, b);
  }
  static DoubleVector floor(DoubleVector a) {
    return _mm512_roundscale_pd(
        a, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
  }
  static Mask greater(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_GT_OQ);
  }
  static DoubleVector select(Mask mask, DoubleVector whenFalse,
                             DoubleVector whenTrue) {
    return _mm512_mask_blend_pd(mask, whenFalse, whenTrue);
  }
  static DoubleVector load(const double *a) { return _mm512_loadu_pd(a); }
  static void store(double *out, DoubleVector a) {
    _mm512_storeu_pd(out, a);
  }
  static IntegerVector asInteger(DoubleVector a) {
    return _mm512_castpd_si512(a);
  }
  static DoubleVector asDouble(IntegerVector a) {
    return _mm512_castsi512_pd(a);
  }
  static IntegerVector bitAnd(IntegerVector a, IntegerVector b) {
    return _mm512_and_si512(a, b);
  }
  static IntegerVector bitOr(IntegerVector a, IntegerVector b) {
    return _mm512_or_si512(a, b);
  }
  static IntegerVector bitXor(IntegerVector a, IntegerVector b) {
    return _mm512_xor_si512(a, b);
  }
  static GatherIndices indices(const int *input, int valid) {
    const int last = input[valid - 1];
    return {input[0], valid > 1 ? input[1] : last,
            valid > 2 ? input[2] : last, valid > 3 ? input[3] : last,
            valid > 4 ? input[4] : last, valid > 5 ? input[5] : last,
            valid > 6 ? input[6] : last, valid > 7 ? input[7] : last};
  }
  static DoubleVector gather(const double *base, GatherIndices indices) {
    return _mm512_set_pd(base[indices[7]], base[indices[6]],
                         base[indices[5]], base[indices[4]],
                         base[indices[3]], base[indices[2]],
                         base[indices[1]], base[indices[0]]);
  }
  template <int A, int B, int C, int MASK_SHIFT>
  static IntegerVector advance(IntegerVector state) {
    const IntegerVector first = _mm512_srli_epi64(
        _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
    const IntegerVector second = _mm512_slli_epi64(
        _mm512_and_si512(
            state, _mm512_set1_epi64(
                       static_cast<long long>(ALL_BITS << MASK_SHIFT))),
        C);
    return _mm512_xor_si512(first, second);
  }
};
#endif

template <class Backend>
void vectorFreshRolls(const ChunkSeeds &seeds, const std::vector<int> &active,
                      std::string_view key, std::vector<double> &rolls) {
  rolls.resize(active.size());
  alignas(64) double output[Backend::LANES];
  for (std::size_t offset = 0; offset < active.size();
       offset += Backend::LANES) {
    const int valid = static_cast<int>(
        std::min<std::size_t>(Backend::LANES, active.size() - offset));
    const int *indices = active.data() + offset;
    auto value = vectorSeedPseudohash<Backend>(
        seeds, indices, valid, static_cast<int>(key.size()));
    value = vectorPseudohashFrom<Backend>(key, value);
    value = vectorAdvanceNode<Backend>(value);
    const auto gatherIndices = Backend::indices(indices, valid);
    const auto hashed = Backend::gather(
        seeds.hashedSeed.data(), gatherIndices);
    value = Backend::mul(
        Backend::add(value, hashed), Backend::set1(0.5));
    Backend::store(output, vectorRandom<Backend>(value));
    for (int lane = 0; lane < valid; ++lane) {
      rolls[offset + lane] = output[lane];
    }
  }
}

template <class Backend>
void vectorSoulFlags(const ChunkSeeds &seeds, const std::vector<int> &active,
                     std::vector<std::uint8_t> &foundSoul) {
  foundSoul.assign(active.size(), 0);
  alignas(64) double rolls[Backend::LANES];
  for (std::size_t offset = 0; offset < active.size();
       offset += Backend::LANES) {
    const int valid = static_cast<int>(
        std::min<std::size_t>(Backend::LANES, active.size() - offset));
    const int *indices = active.data() + offset;
    auto state = vectorSeedPseudohash<Backend>(
        seeds, indices, valid, static_cast<int>(SOUL_TAROT_KEY.size()));
    state = vectorPseudohashFrom<Backend>(SOUL_TAROT_KEY, state);
    const auto gatherIndices = Backend::indices(indices, valid);
    const auto hashed = Backend::gather(
        seeds.hashedSeed.data(), gatherIndices);
    for (int card = 0; card < 5; ++card) {
      state = vectorAdvanceNode<Backend>(state);
      const auto input = Backend::mul(
          Backend::add(state, hashed), Backend::set1(0.5));
      Backend::store(rolls, vectorRandom<Backend>(input));
      for (int lane = 0; lane < valid; ++lane) {
        if (rolls[lane] > SOUL_THRESHOLD) {
          foundSoul[offset + lane] = 1;
        }
      }
    }
  }
}

template <class Backend>
std::uint64_t vectorOpeningGateChunk(
    ChunkSeeds &seeds, std::size_t count, std::vector<std::uint8_t> *answers,
    std::vector<int> &active, std::vector<int> &scratch,
    std::vector<double> &rolls, std::vector<std::uint8_t> &flags) {
  active.resize(count);
  for (std::size_t i = 0; i < count; ++i) {
    active[i] = static_cast<int>(i);
  }

  alignas(64) double hashLanes[Backend::LANES];
  for (std::size_t offset = 0; offset < count; offset += Backend::LANES) {
    const int valid = static_cast<int>(
        std::min<std::size_t>(Backend::LANES, count - offset));
    const auto hash = vectorSeedPseudohash<Backend>(
        seeds, active.data() + offset, valid, 0);
    Backend::store(hashLanes, hash);
    for (int lane = 0; lane < valid; ++lane) {
      seeds.hashedSeed[offset + lane] = hashLanes[lane];
    }
  }

  vectorFreshRolls<Backend>(seeds, active, TAG_KEY, rolls);
  std::vector<int> charm;
  charm.reserve(count / 12 + 8);
  scratch.clear();
  for (std::size_t i = 0; i < count; ++i) {
    const int tag = static_cast<int>(rolls[i] * 24.0);
    if (tag == 10) {
      charm.push_back(static_cast<int>(i));
    } else if (isLockedAnteOneTagIndex(tag)) {
      scratch.push_back(static_cast<int>(i));
    }
  }

  int resample = 2;
  while (!scratch.empty() && resample <= 1000) {
    const std::string key =
        std::string(TAG_KEY) + "_resample" + std::to_string(resample);
    vectorFreshRolls<Backend>(seeds, scratch, key, rolls);
    active.clear();
    for (std::size_t i = 0; i < scratch.size(); ++i) {
      const int tag = static_cast<int>(rolls[i] * 24.0);
      if (tag == 10) {
        charm.push_back(scratch[i]);
      } else if (isLockedAnteOneTagIndex(tag) && resample < 1000) {
        active.push_back(scratch[i]);
      }
    }
    scratch.swap(active);
    ++resample;
  }

  vectorSoulFlags<Backend>(seeds, charm, flags);
  active.clear();
  for (std::size_t i = 0; i < charm.size(); ++i) {
    if (flags[i]) {
      active.push_back(charm[i]);
    }
  }

  vectorFreshRolls<Backend>(seeds, active, LEGENDARY_KEY, rolls);
  std::uint64_t hits = 0;
  for (std::size_t i = 0; i < active.size(); ++i) {
    if (static_cast<int>(rolls[i] * 5.0) == 4) {
      ++hits;
      if (answers != nullptr) {
        (*answers)[active[i]] = 1;
      }
    }
  }
  return hits;
}

void fillChunk(ChunkSeeds &chunk, CompactSeed &seed, std::size_t count) {
  for (std::size_t i = 0; i < count; ++i) {
    chunk.lengths[i] = static_cast<double>(seed.length);
    for (int position = 0; position < 8; ++position) {
      chunk.chars[position][i] = static_cast<unsigned char>(
          seedChars[seed.digits[position]]);
    }
    chunk.identity[i] = static_cast<int>(i);
    seed.next();
  }
}

template <class Backend>
std::uint64_t runVectorSearch(std::size_t sampleCount, std::size_t chunkSize,
                              std::vector<std::uint8_t> *answers = nullptr) {
  ChunkSeeds chunk(chunkSize);
  CompactSeed seed(START_SEED_ID);
  std::vector<int> active;
  std::vector<int> scratch;
  std::vector<double> rolls;
  std::vector<std::uint8_t> flags;
  active.reserve(chunkSize);
  scratch.reserve(chunkSize);
  rolls.reserve(chunkSize);
  flags.reserve(chunkSize);
  if (answers != nullptr) {
    answers->assign(sampleCount, 0);
  }

  std::uint64_t totalHits = 0;
  std::size_t processed = 0;
  while (processed < sampleCount) {
    const std::size_t count = std::min(chunkSize, sampleCount - processed);
    fillChunk(chunk, seed, count);
    std::vector<std::uint8_t> localAnswers;
    if (answers != nullptr) {
      localAnswers.assign(count, 0);
    }
    totalHits += vectorOpeningGateChunk<Backend>(
        chunk, count, answers != nullptr ? &localAnswers : nullptr,
        active, scratch, rolls, flags);
    if (answers != nullptr) {
      std::copy(localAnswers.begin(), localAnswers.end(),
                answers->begin() + processed);
    }
    processed += count;
  }
  return totalHits;
}

std::uint64_t runScalarSearch(std::size_t sampleCount, RandomFunction random,
                              const ByteTable11 *table,
                              std::vector<std::uint8_t> *answers = nullptr) {
  Seed seed(START_SEED_ID);
  if (answers != nullptr) {
    answers->assign(sampleCount, 0);
  }
  std::uint64_t hits = 0;
  for (std::size_t i = 0; i < sampleCount; ++i) {
    const bool passed = scalarOpeningGate(seed, random, table);
    hits += passed;
    if (answers != nullptr) {
      (*answers)[i] = passed ? 1 : 0;
    }
    seed.next();
  }
  return hits;
}

template <typename Function>
double benchmark(Function function, std::uint64_t &checksum) {
  const auto start = std::chrono::steady_clock::now();
  std::uint64_t value = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    value = (value << 9u) ^ function() ^ (value >> 3u);
  }
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - start).count();
  checksum ^= value;
  return seconds;
}

bool compareAnswers(const std::vector<std::uint8_t> &expected,
                    const std::vector<std::uint8_t> &actual,
                    std::string_view label) {
  if (expected.size() != actual.size()) {
    std::cout << label << " answer-size mismatch\n";
    return false;
  }
  for (std::size_t i = 0; i < expected.size(); ++i) {
    if (expected[i] != actual[i]) {
      std::cout << label << " mismatch at seed offset " << i
                << " expected=" << static_cast<int>(expected[i])
                << " actual=" << static_cast<int>(actual[i]) << '\n';
      return false;
    }
  }
  return true;
}

bool verifyCompactHash() {
  Seed reference(START_SEED_ID);
  CompactSeed compact(START_SEED_ID);
  constexpr std::array<int, 6> prefixes = {0, 4, 6, 11, 14, 15};
  for (std::size_t i = 0; i < 65536; ++i) {
    for (int prefix : prefixes) {
      const double expected = reference.pseudohash(prefix);
      const double actual = compactPseudohash(compact, prefix);
      if (std::bit_cast<std::uint64_t>(expected) !=
          std::bit_cast<std::uint64_t>(actual)) {
        std::cerr << "compact hash mismatch offset=" << i
                  << " prefix=" << prefix << '\n';
        return false;
      }
    }
    reference.next();
    compact.next();
  }
  return true;
}

void configureBenchmarkThread() {
#if defined(_WIN32)
  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);
  // Pinning removes migration noise without consuming additional cores.
  constexpr DWORD_PTR affinity = DWORD_PTR{1} << 2;
  if (SetThreadAffinityMask(GetCurrentThread(), affinity) == 0) {
    std::cerr << "warning: thread affinity could not be set\n";
  }
#endif
}

} // namespace

int main() {
  std::cout << std::unitbuf;
  std::cerr << std::unitbuf;
  configureBenchmarkThread();
  const ByteTable11 table = buildByteTable11();
  std::cout << "strict_fp_required=true\n"
            << "sample_count=" << SAMPLE_COUNT << " repeats=" << REPEATS
            << " start_seed_id=" << START_SEED_ID << '\n'
            << "f11_table_bytes=" << sizeof(table) << '\n';

  if (!verifyCompactHash()) {
    return 1;
  }
  std::cout << "compact_hash_status=exact\n";

  std::vector<std::uint8_t> expected;
  std::vector<std::uint8_t> actual;
  const std::uint64_t expectedHits = runScalarSearch(
      VERIFY_COUNT, baselineRandomAdapter, nullptr, &expected);
  std::cout << "scalar_reference_verify_hits=" << expectedHits << '\n';
  const std::uint64_t tableHits = runScalarSearch(
      VERIFY_COUNT, tableRandomAdapter, &table, &actual);
  std::cout << "scalar_f11_verify_hits=" << tableHits << '\n';
  const bool tableAnswersMatch =
      compareAnswers(expected, actual, "scalar_f11");
  std::cout << "scalar_f11_answers_match=" << tableAnswersMatch << '\n';
  if (tableHits != expectedHits || !tableAnswersMatch) {
    std::cerr << "scalar_f11 hit-count mismatch expected=" << expectedHits
              << " actual=" << tableHits << '\n';
    return 1;
  }

#if defined(__AVX2__)
  const std::uint64_t avx2Hits =
      runVectorSearch<Avx2Backend>(VERIFY_COUNT, 1024, &actual);
  std::cout << "avx2_verify_hits=" << avx2Hits << '\n';
  const bool avx2AnswersMatch = compareAnswers(expected, actual, "avx2");
  if (avx2Hits != expectedHits || !avx2AnswersMatch) {
    return 1;
  }
#endif
#if defined(__AVX512F__)
  const std::uint64_t avx512Hits =
      runVectorSearch<Avx512Backend>(VERIFY_COUNT, 1024, &actual);
  std::cout << "avx512_verify_hits=" << avx512Hits << '\n';
  const bool avx512AnswersMatch = compareAnswers(expected, actual, "avx512");
  if (avx512Hits != expectedHits || !avx512AnswersMatch) {
    return 1;
  }
#endif
  std::cout << "differential_seeds=" << VERIFY_COUNT
            << " hits=" << expectedHits << " status=exact\n";

  // Warm code and tables without adding a second worker.
  volatile std::uint64_t warm = runScalarSearch(
      16384, tableRandomAdapter, &table, nullptr);
#if defined(__AVX2__)
  warm ^= runVectorSearch<Avx2Backend>(16384, 256, nullptr);
#endif
#if defined(__AVX512F__)
  warm ^= runVectorSearch<Avx512Backend>(16384, 256, nullptr);
#endif

  std::uint64_t checksum = warm;
  const double scalarSeconds = benchmark(
      [&]() {
        return runScalarSearch(
            SAMPLE_COUNT, baselineRandomAdapter, nullptr, nullptr);
      }, checksum);
  const double tableSeconds = benchmark(
      [&]() {
        return runScalarSearch(
            SAMPLE_COUNT, tableRandomAdapter, &table, nullptr);
      }, checksum);

  const double evaluations = static_cast<double>(SAMPLE_COUNT) * REPEATS;
  auto printResult = [&](std::string_view name, double seconds) {
    std::cout << std::left << std::setw(24) << name
              << " seconds=" << std::fixed << std::setprecision(6) << seconds
              << " Mseeds_per_s=" << std::setprecision(3)
              << evaluations / seconds / 1.0e6
              << " speedup_vs_scalar=" << std::setprecision(3)
              << scalarSeconds / seconds << "x\n";
  };

  printResult("scalar_production_rng", scalarSeconds);
  printResult("scalar_f11_table", tableSeconds);

  constexpr std::array<std::size_t, 5> chunkSizes = {8, 64, 256, 1024, 4096};
#if defined(__AVX2__)
  for (std::size_t chunkSize : chunkSizes) {
    const double seconds = benchmark(
        [&]() {
          return runVectorSearch<Avx2Backend>(
              SAMPLE_COUNT, chunkSize, nullptr);
        }, checksum);
    printResult("avx2_chunk_" + std::to_string(chunkSize), seconds);
  }
#endif
#if defined(__AVX512F__)
  for (std::size_t chunkSize : chunkSizes) {
    const double seconds = benchmark(
        [&]() {
          return runVectorSearch<Avx512Backend>(
              SAMPLE_COUNT, chunkSize, nullptr);
        }, checksum);
    printResult("avx512_chunk_" + std::to_string(chunkSize), seconds);
  }
#endif
  std::cout << "checksum=" << checksum << '\n';
  return 0;
}
