#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <random>
#include <vector>

namespace {

#if defined(__GNUC__) || defined(__clang__)
#define BENCH_NOINLINE __attribute__((noinline))
#elif defined(_MSC_VER)
#define BENCH_NOINLINE __declspec(noinline)
#else
#define BENCH_NOINLINE
#endif

constexpr std::uint64_t ALL_BITS = ~std::uint64_t{0};
constexpr std::size_t SAMPLE_COUNT = 1u << 20;
constexpr int REPEATS = 8;

inline std::uint64_t stepWord(std::uint64_t z, int recurrence) {
  switch (recurrence) {
  case 0:
    return (((z << 31u) ^ z) >> 45u) ^ ((z & (ALL_BITS << 1u)) << 18u);
  case 1:
    return (((z << 19u) ^ z) >> 30u) ^ ((z & (ALL_BITS << 6u)) << 28u);
  case 2:
    return (((z << 24u) ^ z) >> 48u) ^ ((z & (ALL_BITS << 9u)) << 7u);
  default:
    return (((z << 21u) ^ z) >> 39u) ^ ((z & (ALL_BITS << 17u)) << 8u);
  }
}

inline std::uint64_t baselineJump10(std::uint64_t value, int recurrence) {
  for (int i = 0; i < 10; ++i) {
    value = stepWord(value, recurrence);
  }
  return value;
}

inline std::array<std::uint64_t, 4>
baselineJump10State(const std::array<std::uint64_t, 4> &input) {
  std::array<std::uint64_t, 4> state = input;
  for (int step = 0; step < 10; ++step) {
    state[0] = stepWord(state[0], 0);
    state[1] = stepWord(state[1], 1);
    state[2] = stepWord(state[2], 2);
    state[3] = stepWord(state[3], 3);
  }
  return state;
}

#if defined(__AVX2__)
inline __m256i avx2Advance(__m256i state) {
  alignas(32) static constexpr std::uint64_t LEFT_A[4] = {31, 19, 24, 21};
  alignas(32) static constexpr std::uint64_t RIGHT_B[4] = {45, 30, 48, 39};
  alignas(32) static constexpr std::uint64_t LEFT_C[4] = {18, 28, 7, 8};
  alignas(32) static constexpr std::uint64_t MASKS[4] = {
      ALL_BITS << 1u, ALL_BITS << 6u, ALL_BITS << 9u, ALL_BITS << 17u};
  const __m256i a =
      _mm256_load_si256(reinterpret_cast<const __m256i *>(LEFT_A));
  const __m256i b =
      _mm256_load_si256(reinterpret_cast<const __m256i *>(RIGHT_B));
  const __m256i c =
      _mm256_load_si256(reinterpret_cast<const __m256i *>(LEFT_C));
  const __m256i masks =
      _mm256_load_si256(reinterpret_cast<const __m256i *>(MASKS));
  const __m256i first = _mm256_srlv_epi64(
      _mm256_xor_si256(_mm256_sllv_epi64(state, a), state), b);
  const __m256i second =
      _mm256_sllv_epi64(_mm256_and_si256(state, masks), c);
  return _mm256_xor_si256(first, second);
}

inline __m256i avx2Jump(__m256i state, int steps) {
  for (int i = 0; i < steps; ++i) {
    state = avx2Advance(state);
  }
  return state;
}

inline std::array<std::uint64_t, 4>
avx2Jump10State(const std::array<std::uint64_t, 4> &state) {
  const __m256i input = _mm256_loadu_si256(
      reinterpret_cast<const __m256i *>(state.data()));
  const __m256i output = avx2Jump(input, 10);
  std::array<std::uint64_t, 4> result;
  _mm256_storeu_si256(reinterpret_cast<__m256i *>(result.data()), output);
  return result;
}

inline std::uint64_t xorReduce(__m256i value) {
  const __m128i halves = _mm_xor_si128(
      _mm256_castsi256_si128(value), _mm256_extracti128_si256(value, 1));
  return static_cast<std::uint64_t>(_mm_cvtsi128_si64(halves)) ^
         static_cast<std::uint64_t>(_mm_extract_epi64(halves, 1));
}


template <int A, int B, int C, int MASK_SHIFT>
inline __m256i avx2AdvanceAcrossSeeds(__m256i state) {
  const __m256i first = _mm256_srli_epi64(
      _mm256_xor_si256(_mm256_slli_epi64(state, A), state), B);
  const __m256i second = _mm256_slli_epi64(
      _mm256_and_si256(
          state,
          _mm256_set1_epi64x(
              static_cast<long long>(ALL_BITS << MASK_SHIFT))),
      C);
  return _mm256_xor_si256(first, second);
}
#endif

#if defined(__AVX512F__)
template <int A, int B, int C, int MASK_SHIFT>
inline __m512i avx512AdvanceAcrossSeeds(__m512i state) {
  const __m512i first = _mm512_srli_epi64(
      _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
  const __m512i second = _mm512_slli_epi64(
      _mm512_and_si512(
          state,
          _mm512_set1_epi64(
              static_cast<long long>(ALL_BITS << MASK_SHIFT))),
      C);
  return _mm512_xor_si512(first, second);
}
#endif

using ByteTable =
    std::array<std::array<std::array<std::uint64_t, 256>, 8>, 4>;
using NibbleTable =
    std::array<std::array<std::array<std::uint64_t, 16>, 16>, 4>;

ByteTable buildByteTable() {
  ByteTable table{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int position = 0; position < 8; ++position) {
      for (int value = 0; value < 256; ++value) {
        table[recurrence][position][value] = baselineJump10(
            static_cast<std::uint64_t>(value) << (position * 8), recurrence);
      }
    }
  }
  return table;
}

ByteTable buildByteTable11() {
  ByteTable table{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int position = 0; position < 8; ++position) {
      for (int value = 0; value < 256; ++value) {
        const std::uint64_t jump10 = baselineJump10(
            static_cast<std::uint64_t>(value) << (position * 8), recurrence);
        table[recurrence][position][value] = stepWord(jump10, recurrence);
      }
    }
  }
  return table;
}

NibbleTable buildNibbleTable() {
  NibbleTable table{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    for (int position = 0; position < 16; ++position) {
      for (int value = 0; value < 16; ++value) {
        table[recurrence][position][value] = baselineJump10(
            static_cast<std::uint64_t>(value) << (position * 4), recurrence);
      }
    }
  }
  return table;
}

inline std::uint64_t byteJump10(std::uint64_t value, int recurrence,
                                const ByteTable &table) {
  std::uint64_t result = 0;
  for (int position = 0; position < 8; ++position) {
    result ^= table[recurrence][position][value & 0xffu];
    value >>= 8u;
  }
  return result;
}

inline std::uint64_t nibbleJump10(std::uint64_t value, int recurrence,
                                  const NibbleTable &table) {
  std::uint64_t result = 0;
  for (int position = 0; position < 16; ++position) {
    result ^= table[recurrence][position][value & 0x0fu];
    value >>= 4u;
  }
  return result;
}

struct ShiftTerm {
  int shift = 0;
  std::uint64_t outputMask = 0;
};

using ShiftTerms = std::array<std::vector<ShiftTerm>, 4>;

ShiftTerms buildShiftTerms() {
  ShiftTerms result;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    std::array<std::uint64_t, 127> masks{};
    for (int inputBit = 0; inputBit < 64; ++inputBit) {
      const std::uint64_t transformed =
          baselineJump10(std::uint64_t{1} << inputBit, recurrence);
      for (int outputBit = 0; outputBit < 64; ++outputBit) {
        if ((transformed & (std::uint64_t{1} << outputBit)) != 0) {
          masks[inputBit - outputBit + 63] |=
              std::uint64_t{1} << outputBit;
        }
      }
    }
    for (int index = 0; index < 127; ++index) {
      if (masks[index] != 0) {
        result[recurrence].push_back(ShiftTerm{index - 63, masks[index]});
      }
    }
  }
  return result;
}

inline std::uint64_t shiftJump10(std::uint64_t value, int recurrence,
                                 const ShiftTerms &terms) {
  std::uint64_t result = 0;
  for (const ShiftTerm &term : terms[recurrence]) {
    const std::uint64_t shifted = term.shift >= 0
                                      ? value >> term.shift
                                      : value << -term.shift;
    result ^= shifted & term.outputMask;
  }
  return result;
}

// A mechanically synthesized form of the same four GF(2) transforms. Each
// output mask groups matrix entries that share one input-to-output shift.
// Keeping the expressions explicit lets the optimizer use immediate shifts
// and avoids the dynamic loop used by shiftJump10 above.
inline std::uint64_t staticShiftJump10(std::uint64_t value, int recurrence) {
  switch (recurrence) {
  case 0:
    return ((value << 54u) & 0xff80000000000000ull) ^
           ((value << 53u) & 0xffc0000000000000ull) ^
           ((value << 52u) & 0xffe0000000000000ull) ^
           ((value << 22u) & 0x007fffffff800000ull) ^
           ((value << 21u) & 0xffc0000000000000ull) ^
           ((value << 20u) & 0x001fffffffe00000ull) ^
           ((value >> 9u) & 0x007fffffffffffffull) ^
           ((value >> 10u) & 0x003fffffff800000ull) ^
           ((value >> 11u) & 0x001fffffffffffffull) ^
           ((value >> 12u) & 0x00000000001fffffull) ^
           ((value >> 41u) & 0x00000000007fffffull) ^
           ((value >> 43u) & 0x00000000001fffffull);
  case 1:
    return ((value << 48u) & 0xffc0000000000000ull) ^
           ((value << 46u) & 0xfff0000000000000ull) ^
           ((value << 9u) & 0x003fffffffff8000ull) ^
           ((value << 8u) & 0xffffffffffffc000ull) ^
           ((value << 7u) & 0x000fffffffffe000ull) ^
           ((value >> 10u) & 0x003fffffffffffffull) ^
           ((value >> 12u) & 0x000fffffffffffffull) ^
           ((value >> 30u) & 0x0000000000007fffull) ^
           ((value >> 31u) & 0x0000000000003fffull) ^
           ((value >> 32u) & 0x0000000000001fffull) ^
           ((value >> 49u) & 0x0000000000007fffull) ^
           ((value >> 50u) & 0x0000000000003fffull) ^
           ((value >> 51u) & 0x0000000000001fffull);
  case 2:
    return ((value << 39u) & 0xffff000000000000ull) ^
           ((value << 15u) & 0xffffffffff000000ull) ^
           ((value << 8u) & 0x0000fffffffe0000ull) ^
           ((value >> 16u) & 0x0000ffffff000000ull) ^
           ((value >> 23u) & 0x000000000001ffffull) ^
           ((value >> 40u) & 0x0000000000ffffffull) ^
           ((value >> 47u) & 0x000000000001ffffull);
  default:
    return ((value << 33u) & 0xfffc000000000000ull) ^
           ((value << 28u) & 0xffffe00000000000ull) ^
           ((value << 7u) & 0xfffc000000000000ull) ^
           ((value << 2u) & 0x00001ffffff80000ull) ^
           ((value >> 14u) & 0x0003fffffffffff8ull) ^
           ((value >> 19u) & 0x00001fffffffffffull) ^
           ((value >> 24u) & 0x000000000007ffffull) ^
           ((value >> 40u) & 0x0000000000000007ull) ^
           ((value >> 45u) & 0x000000000007ffffull) ^
           ((value >> 61u) & 0x0000000000000007ull);
  }
}

template <typename Function>
double benchmark(const std::vector<std::array<std::uint64_t, 4>> &inputs,
                 Function function, std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (const auto &state : inputs) {
      local ^= function(state[0], 0);
      local += function(state[1], 1);
      local ^= function(state[2], 2);
      local += function(state[3], 3);
    }
  }
  const auto finished = std::chrono::steady_clock::now();
  checksum ^= local;
  return std::chrono::duration<double>(finished - started).count();
}

template <typename Function>
double benchmarkWholeState(
    const std::vector<std::array<std::uint64_t, 4>> &inputs,
    Function function, std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (const auto &input : inputs) {
      const auto state = function(input);
      local ^= state[0];
      local += state[1];
      local ^= state[2];
      local += state[3];
    }
  }
  checksum ^= local;
  return std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      started)
      .count();
}

inline void initFromDouble(double seed, std::uint64_t state[4]) {
  double value = seed;
  std::uint64_t repairBits = 0x11090601u;
  for (int i = 0; i < 4; ++i) {
    const std::uint64_t minimum = std::uint64_t{1} << (repairBits & 255u);
    repairBits >>= 8u;
    value = value * 3.14159265358979323846 + 2.7182818284590452354;
    union {
      double dbl;
      std::uint64_t bits;
    } converted{};
    converted.dbl = value;
    if (converted.bits < minimum) {
      converted.bits += minimum;
    }
    state[i] = converted.bits;
  }
}

inline void initFromDoubleFma(double seed, std::uint64_t state[4]) {
  double value = seed;
  std::uint64_t repairBits = 0x11090601u;
  for (int i = 0; i < 4; ++i) {
    const std::uint64_t minimum = std::uint64_t{1} << (repairBits & 255u);
    repairBits >>= 8u;
    value = std::fma(value, 3.14159265358979323846,
                     2.7182818284590452354);
    union {
      double dbl;
      std::uint64_t bits;
    } converted{};
    converted.dbl = value;
    if (converted.bits < minimum) {
      converted.bits += minimum;
    }
    state[i] = converted.bits;
  }
}

inline std::uint64_t advanceState(std::uint64_t state[4]) {
  std::uint64_t result = 0;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    state[recurrence] = stepWord(state[recurrence], recurrence);
    result ^= state[recurrence];
  }
  return result;
}

BENCH_NOINLINE std::uint64_t baselineRandomBits(double seed) {
  std::uint64_t state[4];
  initFromDouble(seed, state);
  for (int i = 0; i < 10; ++i) {
    advanceState(state);
  }
  return (advanceState(state) & 4503599627370495ull) |
         4607182418800017408ull;
}

BENCH_NOINLINE std::uint64_t baselineRandomBitsFma(double seed) {
  std::uint64_t state[4];
  initFromDoubleFma(seed, state);
  for (int i = 0; i < 10; ++i) {
    advanceState(state);
  }
  return (advanceState(state) & 4503599627370495ull) |
         4607182418800017408ull;
}

BENCH_NOINLINE std::uint64_t byteJumpRandomBits(double seed,
                                                const ByteTable &table) {
  std::uint64_t state[4];
  initFromDouble(seed, state);
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    state[recurrence] = byteJump10(state[recurrence], recurrence, table);
  }
  return (advanceState(state) & 4503599627370495ull) |
         4607182418800017408ull;
}

BENCH_NOINLINE std::uint64_t byteJump11RandomBits(
    double seed, const ByteTable &table) {
  std::uint64_t state[4];
  initFromDouble(seed, state);
  std::uint64_t result = 0;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    result ^= byteJump10(state[recurrence], recurrence, table);
  }
  return (result & 4503599627370495ull) | 4607182418800017408ull;
}

#if defined(__AVX2__)
BENCH_NOINLINE std::uint64_t avx2Jump11RandomBits(double seed) {
  alignas(32) std::uint64_t state[4];
  initFromDouble(seed, state);
  const __m256i input =
      _mm256_load_si256(reinterpret_cast<const __m256i *>(state));
  const std::uint64_t result = xorReduce(avx2Jump(input, 11));
  return (result & 4503599627370495ull) | 4607182418800017408ull;
}


BENCH_NOINLINE void avx2Batch4RandomBits(const double *seeds,
                                         std::uint64_t *outputs) {
  alignas(32) std::uint64_t initialized[4][4];
  for (int lane = 0; lane < 4; ++lane) {
    initFromDouble(seeds[lane], initialized[lane]);
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
    z0 = avx2AdvanceAcrossSeeds<31, 45, 18, 1>(z0);
    z1 = avx2AdvanceAcrossSeeds<19, 30, 28, 6>(z1);
    z2 = avx2AdvanceAcrossSeeds<24, 48, 7, 9>(z2);
    z3 = avx2AdvanceAcrossSeeds<21, 39, 8, 17>(z3);
  }
  const __m256i mantissa = _mm256_set1_epi64x(4503599627370495ll);
  const __m256i exponent = _mm256_set1_epi64x(4607182418800017408ll);
  const __m256i result = _mm256_or_si256(
      _mm256_and_si256(
          _mm256_xor_si256(_mm256_xor_si256(z0, z1),
                           _mm256_xor_si256(z2, z3)),
          mantissa),
      exponent);
  _mm256_storeu_si256(reinterpret_cast<__m256i *>(outputs), result);
}
#endif

#if defined(__AVX512F__)
BENCH_NOINLINE void avx512Batch8RandomBits(const double *seeds,
                                           std::uint64_t *outputs) {
  alignas(64) std::uint64_t initialized[8][4];
  for (int lane = 0; lane < 8; ++lane) {
    initFromDouble(seeds[lane], initialized[lane]);
  }
  alignas(64) std::uint64_t transposed[4][8];
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
    z0 = avx512AdvanceAcrossSeeds<31, 45, 18, 1>(z0);
    z1 = avx512AdvanceAcrossSeeds<19, 30, 28, 6>(z1);
    z2 = avx512AdvanceAcrossSeeds<24, 48, 7, 9>(z2);
    z3 = avx512AdvanceAcrossSeeds<21, 39, 8, 17>(z3);
  }
  const __m512i result = _mm512_or_si512(
      _mm512_and_si512(
          _mm512_xor_si512(_mm512_xor_si512(z0, z1),
                           _mm512_xor_si512(z2, z3)),
          _mm512_set1_epi64(4503599627370495ll)),
      _mm512_set1_epi64(4607182418800017408ll));
  _mm512_storeu_si512(outputs, result);
}
#endif

BENCH_NOINLINE void baselineBatch8RandomBits(const double *seeds,
                                             std::uint64_t *outputs) {
  for (int lane = 0; lane < 8; ++lane) {
    outputs[lane] = baselineRandomBits(seeds[lane]);
  }
}

BENCH_NOINLINE void byte11Batch8RandomBits(const double *seeds,
                                           std::uint64_t *outputs,
                                           const ByteTable &table) {
  for (int lane = 0; lane < 8; ++lane) {
    outputs[lane] = byteJump11RandomBits(seeds[lane], table);
  }
}

BENCH_NOINLINE std::uint64_t hybridJumpRandomBits(
    double seed, const ByteTable &table, const ShiftTerms &terms) {
  std::uint64_t state[4];
  initFromDouble(seed, state);
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    state[recurrence] = recurrence == 2
                            ? shiftJump10(state[recurrence], recurrence, terms)
                            : byteJump10(state[recurrence], recurrence, table);
  }
  return (advanceState(state) & 4503599627370495ull) |
         4607182418800017408ull;
}

BENCH_NOINLINE std::uint64_t staticShiftRandomBits(double seed) {
  std::uint64_t state[4];
  initFromDouble(seed, state);
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    state[recurrence] = staticShiftJump10(state[recurrence], recurrence);
  }
  return (advanceState(state) & 4503599627370495ull) |
         4607182418800017408ull;
}

template <typename Function>
double benchmarkRandom(const std::vector<double> &inputs, Function function,
                       std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (double seed : inputs) {
      local ^= function(seed);
      local = (local << 7u) | (local >> 57u);
    }
  }
  const auto finished = std::chrono::steady_clock::now();
  checksum ^= local;
  return std::chrono::duration<double>(finished - started).count();
}

template <typename Function>
double benchmarkBatch8(const std::vector<double> &inputs, Function function,
                       std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  alignas(64) std::uint64_t outputs[8];
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (std::size_t index = 0; index < inputs.size(); index += 8) {
      function(inputs.data() + index, outputs);
      for (std::uint64_t output : outputs) {
        local ^= output;
        local = (local << 7u) | (local >> 57u);
      }
    }
  }
  checksum ^= local;
  return std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      started)
      .count();
}

} // namespace

int main() {
  const ByteTable byteTable = buildByteTable();
  const ByteTable byteTable11 = buildByteTable11();
  const NibbleTable nibbleTable = buildNibbleTable();
  const ShiftTerms shiftTerms = buildShiftTerms();

  std::mt19937_64 random(0x5eed1234u);
  std::vector<std::array<std::uint64_t, 4>> inputs(SAMPLE_COUNT);
  std::vector<double> doubleInputs(SAMPLE_COUNT);
  for (auto &state : inputs) {
    for (std::uint64_t &word : state) {
      word = random();
    }
  }
  for (double &value : doubleInputs) {
    value = std::generate_canonical<double, 53>(random);
  }

  for (const auto &state : inputs) {
#if defined(__AVX2__)
    const auto avx2State = avx2Jump10State(state);
#endif
    for (int recurrence = 0; recurrence < 4; ++recurrence) {
      const std::uint64_t expected = baselineJump10(state[recurrence], recurrence);
      if (byteJump10(state[recurrence], recurrence, byteTable) != expected ||
          nibbleJump10(state[recurrence], recurrence, nibbleTable) != expected ||
          shiftJump10(state[recurrence], recurrence, shiftTerms) != expected ||
          staticShiftJump10(state[recurrence], recurrence) != expected
#if defined(__AVX2__)
          || avx2State[recurrence] != expected
#endif
          ) {
        std::cerr << "Differential failure\n";
        return 1;
      }
    }
  }
  for (double value : doubleInputs) {
    if (baselineRandomBits(value) != byteJumpRandomBits(value, byteTable) ||
        baselineRandomBits(value) !=
            byteJump11RandomBits(value, byteTable11) ||
#if defined(__AVX2__)
        baselineRandomBits(value) != avx2Jump11RandomBits(value) ||
#endif
        baselineRandomBits(value) !=
            hybridJumpRandomBits(value, byteTable, shiftTerms) ||
        baselineRandomBits(value) != staticShiftRandomBits(value)) {
      std::cerr << "Full random differential failure\n";
      return 1;
    }
  }
  std::uint64_t baselineDigest = 1469598103934665603ull;
  std::size_t fmaMismatchCount = 0;
  for (double value : doubleInputs) {
    baselineDigest ^= baselineRandomBits(value);
    baselineDigest *= 1099511628211ull;
    fmaMismatchCount +=
        baselineRandomBits(value) != baselineRandomBitsFma(value) ? 1 : 0;
  }
  for (std::size_t index = 0; index < doubleInputs.size(); index += 8) {
    alignas(64) std::uint64_t expected[8];
    alignas(64) std::uint64_t actual[8];
    baselineBatch8RandomBits(doubleInputs.data() + index, expected);
#if defined(__AVX2__)
    avx2Batch4RandomBits(doubleInputs.data() + index, actual);
    avx2Batch4RandomBits(doubleInputs.data() + index + 4, actual + 4);
    for (int lane = 0; lane < 8; ++lane) {
      if (actual[lane] != expected[lane]) {
        std::cerr << "AVX2 batch differential failure\n";
        return 1;
      }
    }
#endif
#if defined(__AVX512F__)
    avx512Batch8RandomBits(doubleInputs.data() + index, actual);
    for (int lane = 0; lane < 8; ++lane) {
      if (actual[lane] != expected[lane]) {
        std::cerr << "AVX-512 batch differential failure\n";
        return 1;
      }
    }
#endif
  }

  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    std::cout << "recurrence " << recurrence
              << " shift_terms=" << shiftTerms[recurrence].size() << '\n';
  }
  std::cout << "byte_table_bytes=" << sizeof(ByteTable) << '\n';
  std::cout << "nibble_table_bytes=" << sizeof(NibbleTable) << '\n';

  std::uint64_t checksum = 0;
  const double baselineSeconds = benchmark(
      inputs, [](std::uint64_t value, int recurrence) {
        return baselineJump10(value, recurrence);
      }, checksum);
  const double byteSeconds = benchmark(
      inputs, [&byteTable](std::uint64_t value, int recurrence) {
        return byteJump10(value, recurrence, byteTable);
      }, checksum);
  const double nibbleSeconds = benchmark(
      inputs, [&nibbleTable](std::uint64_t value, int recurrence) {
        return nibbleJump10(value, recurrence, nibbleTable);
      }, checksum);
  const double shiftSeconds = benchmark(
      inputs, [&shiftTerms](std::uint64_t value, int recurrence) {
        return shiftJump10(value, recurrence, shiftTerms);
      }, checksum);
  const double staticShiftSeconds = benchmark(
      inputs, [](std::uint64_t value, int recurrence) {
        return staticShiftJump10(value, recurrence);
      }, checksum);

  const double directBaselineSeconds = benchmarkWholeState(
      inputs, baselineJump10State, checksum);
#if defined(__AVX2__)
  const double avx2Seconds = benchmarkWholeState(
      inputs, avx2Jump10State, checksum);
#endif

  const double stateCount = static_cast<double>(SAMPLE_COUNT) * REPEATS;
  auto print = [stateCount, baselineSeconds](const char *name, double seconds) {
    std::cout << std::left << std::setw(10) << name << " seconds=" << std::fixed
              << std::setprecision(6) << seconds
              << " ns_per_4word_state=" << std::setprecision(2)
              << seconds * 1.0e9 / stateCount
              << " speedup=" << std::setprecision(3)
              << baselineSeconds / seconds << "x\n";
  };
  print("baseline", baselineSeconds);
  print("byte", byteSeconds);
  print("nibble", nibbleSeconds);
  print("shift", shiftSeconds);
  print("static", staticShiftSeconds);
  std::cout << "direct_scalar seconds=" << std::fixed << std::setprecision(6)
            << directBaselineSeconds << " ns_per_4word_state="
            << std::setprecision(2) << directBaselineSeconds * 1.0e9 / stateCount
            << "\n";
#if defined(__AVX2__)
  std::cout << "direct_avx2   seconds=" << std::fixed << std::setprecision(6)
            << avx2Seconds << " ns_per_4word_state=" << std::setprecision(2)
            << avx2Seconds * 1.0e9 / stateCount << " speedup="
            << std::setprecision(3) << directBaselineSeconds / avx2Seconds
            << "x\n";
#endif
  const double baselineRandomSeconds = benchmarkRandom(
      doubleInputs, [](double seed) { return baselineRandomBits(seed); },
      checksum);
  const double byteRandomSeconds = benchmarkRandom(
      doubleInputs,
      [&byteTable](double seed) { return byteJumpRandomBits(seed, byteTable); },
      checksum);
  const double byte11RandomSeconds = benchmarkRandom(
      doubleInputs,
      [&byteTable11](double seed) {
        return byteJump11RandomBits(seed, byteTable11);
      },
      checksum);
#if defined(__AVX2__)
  const double avx2RandomSeconds = benchmarkRandom(
      doubleInputs,
      [](double seed) { return avx2Jump11RandomBits(seed); }, checksum);
#endif
  const double hybridRandomSeconds = benchmarkRandom(
      doubleInputs,
      [&byteTable, &shiftTerms](double seed) {
        return hybridJumpRandomBits(seed, byteTable, shiftTerms);
      },
      checksum);
  const double staticRandomSeconds = benchmarkRandom(
      doubleInputs, [](double seed) { return staticShiftRandomBits(seed); },
      checksum);
  const double baselineBatchSeconds = benchmarkBatch8(
      doubleInputs,
      [](const double *seeds, std::uint64_t *outputs) {
        baselineBatch8RandomBits(seeds, outputs);
      },
      checksum);
  const double byteBatchSeconds = benchmarkBatch8(
      doubleInputs,
      [&byteTable11](const double *seeds, std::uint64_t *outputs) {
        byte11Batch8RandomBits(seeds, outputs, byteTable11);
      },
      checksum);
#if defined(__AVX2__)
  const double avx2BatchSeconds = benchmarkBatch8(
      doubleInputs,
      [](const double *seeds, std::uint64_t *outputs) {
        avx2Batch4RandomBits(seeds, outputs);
        avx2Batch4RandomBits(seeds + 4, outputs + 4);
      },
      checksum);
#endif
#if defined(__AVX512F__)
  const double avx512BatchSeconds = benchmarkBatch8(
      doubleInputs,
      [](const double *seeds, std::uint64_t *outputs) {
        avx512Batch8RandomBits(seeds, outputs);
      },
      checksum);
#endif
  std::cout << "full_rng_baseline seconds=" << std::fixed
            << std::setprecision(6) << baselineRandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << baselineRandomSeconds * 1.0e9 / stateCount << '\n';
  std::cout << "full_rng_byte     seconds=" << std::fixed
            << std::setprecision(6) << byteRandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << byteRandomSeconds * 1.0e9 / stateCount
            << " speedup=" << std::setprecision(3)
            << baselineRandomSeconds / byteRandomSeconds << "x\n";
  std::cout << "full_rng_byte11   seconds=" << std::fixed
            << std::setprecision(6) << byte11RandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << byte11RandomSeconds * 1.0e9 / stateCount
            << " speedup=" << std::setprecision(3)
            << baselineRandomSeconds / byte11RandomSeconds << "x\n";
#if defined(__AVX2__)
  std::cout << "full_rng_avx2     seconds=" << std::fixed
            << std::setprecision(6) << avx2RandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << avx2RandomSeconds * 1.0e9 / stateCount
            << " speedup=" << std::setprecision(3)
            << baselineRandomSeconds / avx2RandomSeconds << "x\n";
#endif
  std::cout << "full_rng_hybrid   seconds=" << std::fixed
            << std::setprecision(6) << hybridRandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << hybridRandomSeconds * 1.0e9 / stateCount
            << " speedup=" << std::setprecision(3)
            << baselineRandomSeconds / hybridRandomSeconds << "x\n";
  std::cout << "full_rng_static   seconds=" << std::fixed
            << std::setprecision(6) << staticRandomSeconds
            << " ns_per_random=" << std::setprecision(2)
            << staticRandomSeconds * 1.0e9 / stateCount
            << " speedup=" << std::setprecision(3)
            << baselineRandomSeconds / staticRandomSeconds << "x\n";
  auto printBatch = [stateCount, baselineBatchSeconds](const char *name,
                                                       double seconds) {
    std::cout << std::left << std::setw(20) << name << " seconds="
              << std::fixed << std::setprecision(6) << seconds
              << " ns_per_random=" << std::setprecision(2)
              << seconds * 1.0e9 / stateCount << " speedup="
              << std::setprecision(3) << baselineBatchSeconds / seconds
              << "x\n";
  };
  printBatch("batch8_scalar", baselineBatchSeconds);
  printBatch("batch8_byte11", byteBatchSeconds);
#if defined(__AVX2__)
  printBatch("batch8_avx2_2x4", avx2BatchSeconds);
#endif
#if defined(__AVX512F__)
  printBatch("batch8_avx512", avx512BatchSeconds);
#endif
  std::cout << "checksum=" << checksum << '\n';
  std::cout << "baseline_digest=" << baselineDigest << '\n';
  std::cout << "fma_mismatches=" << fmaMismatchCount << "/"
            << doubleInputs.size() << '\n';
  return 0;
}
