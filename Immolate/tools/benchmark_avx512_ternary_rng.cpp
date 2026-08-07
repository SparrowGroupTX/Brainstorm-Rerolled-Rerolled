#include "../src/util.hpp"

#include <algorithm>
#include <bit>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <random>
#include <vector>

namespace {

constexpr std::uint64_t allBits = ~std::uint64_t{0};
constexpr std::uint64_t randomMantissa = 4503599627370495ull;
constexpr std::uint64_t oneExponent = 4607182418800017408ull;
constexpr double luaPi = 3.14159265358979323846;
constexpr double luaE = 2.7182818284590452354;
constexpr std::size_t sampleCount = 1u << 20;
constexpr int repeats = 32;

template <int A, int B, int C, int maskShift>
inline __m512i advanceBaseline(__m512i state) {
  const __m512i first = _mm512_srli_epi64(
      _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
  const __m512i second = _mm512_slli_epi64(
      _mm512_and_si512(
          state, _mm512_set1_epi64(static_cast<long long>(
                     allBits << maskShift))),
      C);
  return _mm512_xor_si512(first, second);
}

template <int A, int B, int C, int maskShift>
inline __m512i advanceTernary(__m512i state) {
  const __m512i first = _mm512_srli_epi64(
      _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
  const __m512i shifted = _mm512_slli_epi64(state, C);
  const __m512i shiftedMask = _mm512_set1_epi64(
      static_cast<long long>((allBits << maskShift) << C));
  // a XOR (b AND c)
  return _mm512_ternarylogic_epi64(first, shifted, shiftedMask, 0x78);
}

template <int shift>
inline __m512i addLeftMasked(__m512i result, __m512i value,
                             std::uint64_t mask) {
  return _mm512_ternarylogic_epi64(
      result, _mm512_slli_epi64(value, shift),
      _mm512_set1_epi64(static_cast<long long>(mask)), 0x78);
}

template <int shift>
inline __m512i addRightMasked(__m512i result, __m512i value,
                              std::uint64_t mask) {
  return _mm512_ternarylogic_epi64(
      result, _mm512_srli_epi64(value, shift),
      _mm512_set1_epi64(static_cast<long long>(mask)), 0x78);
}

// Mechanically synthesized exact ten-step GF(2) transforms. One ordinary
// recurrence below advances the result to the eleven steps used by Lua.
template <int recurrence>
inline __m512i staticJump10(__m512i value) {
  __m512i result = _mm512_setzero_si512();
  if constexpr (recurrence == 0) {
    result = addLeftMasked<54>(result, value, 0xff80000000000000ull);
    result = addLeftMasked<53>(result, value, 0xffc0000000000000ull);
    result = addLeftMasked<52>(result, value, 0xffe0000000000000ull);
    result = addLeftMasked<22>(result, value, 0x007fffffff800000ull);
    result = addLeftMasked<21>(result, value, 0xffc0000000000000ull);
    result = addLeftMasked<20>(result, value, 0x001fffffffe00000ull);
    result = addRightMasked<9>(result, value, 0x007fffffffffffffull);
    result = addRightMasked<10>(result, value, 0x003fffffff800000ull);
    result = addRightMasked<11>(result, value, 0x001fffffffffffffull);
    result = addRightMasked<12>(result, value, 0x00000000001fffffull);
    result = addRightMasked<41>(result, value, 0x00000000007fffffull);
    result = addRightMasked<43>(result, value, 0x00000000001fffffull);
  } else if constexpr (recurrence == 1) {
    result = addLeftMasked<48>(result, value, 0xffc0000000000000ull);
    result = addLeftMasked<46>(result, value, 0xfff0000000000000ull);
    result = addLeftMasked<9>(result, value, 0x003fffffffff8000ull);
    result = addLeftMasked<8>(result, value, 0xffffffffffffc000ull);
    result = addLeftMasked<7>(result, value, 0x000fffffffffe000ull);
    result = addRightMasked<10>(result, value, 0x003fffffffffffffull);
    result = addRightMasked<12>(result, value, 0x000fffffffffffffull);
    result = addRightMasked<30>(result, value, 0x0000000000007fffull);
    result = addRightMasked<31>(result, value, 0x0000000000003fffull);
    result = addRightMasked<32>(result, value, 0x0000000000001fffull);
    result = addRightMasked<49>(result, value, 0x0000000000007fffull);
    result = addRightMasked<50>(result, value, 0x0000000000003fffull);
    result = addRightMasked<51>(result, value, 0x0000000000001fffull);
  } else if constexpr (recurrence == 2) {
    result = addLeftMasked<39>(result, value, 0xffff000000000000ull);
    result = addLeftMasked<15>(result, value, 0xffffffffff000000ull);
    result = addLeftMasked<8>(result, value, 0x0000fffffffe0000ull);
    result = addRightMasked<16>(result, value, 0x0000ffffff000000ull);
    result = addRightMasked<23>(result, value, 0x000000000001ffffull);
    result = addRightMasked<40>(result, value, 0x0000000000ffffffull);
    result = addRightMasked<47>(result, value, 0x000000000001ffffull);
  } else {
    result = addLeftMasked<33>(result, value, 0xfffc000000000000ull);
    result = addLeftMasked<28>(result, value, 0xffffe00000000000ull);
    result = addLeftMasked<7>(result, value, 0xfffc000000000000ull);
    result = addLeftMasked<2>(result, value, 0x00001ffffff80000ull);
    result = addRightMasked<14>(result, value, 0x0003fffffffffff8ull);
    result = addRightMasked<19>(result, value, 0x00001fffffffffffull);
    result = addRightMasked<24>(result, value, 0x000000000007ffffull);
    result = addRightMasked<40>(result, value, 0x0000000000000007ull);
    result = addRightMasked<45>(result, value, 0x000000000007ffffull);
    result = addRightMasked<61>(result, value, 0x0000000000000007ull);
  }
  return result;
}

// Direct eleven-step transforms synthesized only for the 52 output bits Lua
// keeps. This can discard high state bits and the separate final recurrence.
template <int recurrence>
inline __m512i staticJump11Mantissa(__m512i value) {
  __m512i result = _mm512_setzero_si512();
  if constexpr (recurrence == 0) {
    result = addLeftMasked<40>(result, value, 0x000ffe0000000000ull);
    result = addLeftMasked<38>(result, value, 0x000fff8000000000ull);
    result = addLeftMasked<9>(result, value, 0x000ffffffffffc00ull);
    result = addLeftMasked<8>(result, value, 0x000ffe0000000000ull);
    result = addLeftMasked<7>(result, value, 0x000fffffffffff00ull);
    result = addLeftMasked<6>(result, value, 0x0000007fffffff80ull);
    result = addRightMasked<23>(result, value, 0x000001fffffffc00ull);
    result = addRightMasked<25>(result, value, 0x0000007fffffff00ull);
    result = addRightMasked<26>(result, value, 0x000000000000007full);
    result = addRightMasked<54>(result, value, 0x00000000000003ffull);
    result = addRightMasked<56>(result, value, 0x00000000000000ffull);
    result = addRightMasked<57>(result, value, 0x000000000000007full);
  } else if constexpr (recurrence == 1) {
    result = addLeftMasked<37>(result, value, 0x000ff80000000000ull);
    result = addLeftMasked<36>(result, value, 0x000ffc0000000000ull);
    result = addLeftMasked<35>(result, value, 0x000ffe0000000000ull);
    result = addLeftMasked<18>(result, value, 0x000fffffff000000ull);
    result = addLeftMasked<16>(result, value, 0x000fffffffc00000ull);
    result = addRightMasked<2>(result, value, 0x000007fffffffff0ull);
    result = addRightMasked<3>(result, value, 0x000003fffffffff8ull);
    result = addRightMasked<4>(result, value, 0x000001fffffffffcull);
    result = addRightMasked<21>(result, value, 0x000007ffff000000ull);
    result = addRightMasked<22>(result, value, 0x000003ffffffffffull);
    result = addRightMasked<23>(result, value, 0x000001ffffc00000ull);
    result = addRightMasked<40>(result, value, 0x0000000000ffffffull);
    result = addRightMasked<41>(result, value, 0x000000000000000full);
    result = addRightMasked<42>(result, value, 0x00000000003ffff8ull);
    result = addRightMasked<43>(result, value, 0x0000000000000003ull);
    result = addRightMasked<60>(result, value, 0x000000000000000full);
    result = addRightMasked<61>(result, value, 0x0000000000000007ull);
    result = addRightMasked<62>(result, value, 0x0000000000000003ull);
  } else if constexpr (recurrence == 2) {
    result = addLeftMasked<22>(result, value, 0x000fffff80000000ull);
    result = addLeftMasked<15>(result, value, 0x000fffffff000000ull);
    result = addRightMasked<9>(result, value, 0x000fffff80000000ull);
    result = addRightMasked<16>(result, value, 0x0000000000ffffffull);
    result = addRightMasked<33>(result, value, 0x000000007fffffffull);
    result = addRightMasked<40>(result, value, 0x0000000000ffffffull);
  } else {
    result = addLeftMasked<10>(result, value, 0x000ffffff8000000ull);
    result = addRightMasked<6>(result, value, 0x000ffffffffff800ull);
    result = addRightMasked<11>(result, value, 0x000fffffffffffc0ull);
    result = addRightMasked<16>(result, value, 0x0000000007fffffeull);
    result = addRightMasked<32>(result, value, 0x00000000000007ffull);
    result = addRightMasked<37>(result, value, 0x0000000007ffffc0ull);
    result = addRightMasked<42>(result, value, 0x0000000000000001ull);
    result = addRightMasked<53>(result, value, 0x00000000000007ffull);
    result = addRightMasked<58>(result, value, 0x000000000000003full);
    result = addRightMasked<63>(result, value, 0x0000000000000001ull);
  }
  return result;
}

template <bool ternary>
inline __m512d vectorRandom(__m512d seed) {
  __m512d value = seed;
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state0 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state1 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state2 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state3 = _mm512_castpd_si512(value);

  for (int step = 0; step < 11; ++step) {
    if constexpr (ternary) {
      state0 = advanceTernary<31, 45, 18, 1>(state0);
      state1 = advanceTernary<19, 30, 28, 6>(state1);
      state2 = advanceTernary<24, 48, 7, 9>(state2);
      state3 = advanceTernary<21, 39, 8, 17>(state3);
    } else {
      state0 = advanceBaseline<31, 45, 18, 1>(state0);
      state1 = advanceBaseline<19, 30, 28, 6>(state1);
      state2 = advanceBaseline<24, 48, 7, 9>(state2);
      state3 = advanceBaseline<21, 39, 8, 17>(state3);
    }
  }

  __m512i bits;
  if constexpr (ternary) {
    const __m512i firstThree = _mm512_ternarylogic_epi64(
        state0, state1, state2, 0x96);
    const __m512i combined = _mm512_xor_si512(firstThree, state3);
    bits = _mm512_ternarylogic_epi64(
        combined, _mm512_set1_epi64(
                      static_cast<long long>(randomMantissa)),
        _mm512_set1_epi64(static_cast<long long>(oneExponent)), 0xea);
  } else {
    bits = _mm512_or_si512(
        _mm512_and_si512(
            _mm512_xor_si512(_mm512_xor_si512(state0, state1),
                             _mm512_xor_si512(state2, state3)),
            _mm512_set1_epi64(static_cast<long long>(randomMantissa))),
        _mm512_set1_epi64(static_cast<long long>(oneExponent)));
  }
  return _mm512_sub_pd(
      _mm512_castsi512_pd(bits), _mm512_set1_pd(1.0));
}

inline __m512d vectorRandomStatic(__m512d seed) {
  __m512d value = seed;
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state0 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state1 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state2 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  __m512i state3 = _mm512_castpd_si512(value);

  state0 = advanceTernary<31, 45, 18, 1>(staticJump10<0>(state0));
  state1 = advanceTernary<19, 30, 28, 6>(staticJump10<1>(state1));
  state2 = advanceTernary<24, 48, 7, 9>(staticJump10<2>(state2));
  state3 = advanceTernary<21, 39, 8, 17>(staticJump10<3>(state3));

  const __m512i firstThree = _mm512_ternarylogic_epi64(
      state0, state1, state2, 0x96);
  const __m512i combined = _mm512_xor_si512(firstThree, state3);
  const __m512i bits = _mm512_ternarylogic_epi64(
      combined,
      _mm512_set1_epi64(static_cast<long long>(randomMantissa)),
      _mm512_set1_epi64(static_cast<long long>(oneExponent)), 0xea);
  return _mm512_sub_pd(
      _mm512_castsi512_pd(bits), _mm512_set1_pd(1.0));
}

inline __m512d vectorRandomDirectStatic(__m512d seed) {
  __m512d value = seed;
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  const __m512i state0 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  const __m512i state1 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  const __m512i state2 = _mm512_castpd_si512(value);
  value = _mm512_add_pd(
      _mm512_mul_pd(value, _mm512_set1_pd(luaPi)),
      _mm512_set1_pd(luaE));
  const __m512i state3 = _mm512_castpd_si512(value);

  const __m512i output0 = staticJump11Mantissa<0>(state0);
  const __m512i output1 = staticJump11Mantissa<1>(state1);
  const __m512i output2 = staticJump11Mantissa<2>(state2);
  const __m512i output3 = staticJump11Mantissa<3>(state3);
  const __m512i firstThree = _mm512_ternarylogic_epi64(
      output0, output1, output2, 0x96);
  const __m512i combined = _mm512_xor_si512(firstThree, output3);
  const __m512i bits = _mm512_or_si512(
      combined, _mm512_set1_epi64(static_cast<long long>(oneExponent)));
  return _mm512_sub_pd(
      _mm512_castsi512_pd(bits), _mm512_set1_pd(1.0));
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runBaseline(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(
                      vectorRandom<false>(_mm512_loadu_pd(
                          inputs.data() + offset))));
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) {
    result ^= lane;
  }
  return result;
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runTernary(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(
                      vectorRandom<true>(_mm512_loadu_pd(
                          inputs.data() + offset))));
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) {
    result ^= lane;
  }
  return result;
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runStatic(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(
                      vectorRandomStatic(_mm512_loadu_pd(
                          inputs.data() + offset))));
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) {
    result ^= lane;
  }
  return result;
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runDirectStatic(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(
                      vectorRandomDirectStatic(_mm512_loadu_pd(
                          inputs.data() + offset))));
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) {
    result ^= lane;
  }
  return result;
}

template <class Function>
double benchmark(Function function, std::uint64_t& checksum) {
  const auto start = std::chrono::steady_clock::now();
  for (int repeat = 0; repeat < repeats; ++repeat) {
    checksum ^= function(repeat) + static_cast<std::uint64_t>(repeat);
  }
  return std::chrono::duration<double>(
      std::chrono::steady_clock::now() - start).count();
}

double median(std::vector<double> values) {
  std::sort(values.begin(), values.end());
  return values[values.size() / 2];
}

} // namespace

int main() {
  std::vector<double> inputs(sampleCount);
  std::mt19937_64 random(0x9e3779b97f4a7c15ull);
  for (double& input : inputs) {
    input = static_cast<double>(random() & ((std::uint64_t{1} << 53) - 1))
        / static_cast<double>(std::uint64_t{1} << 53);
  }

  alignas(64) double baselineLanes[8];
  alignas(64) double candidateLanes[8];
  alignas(64) double staticLanes[8];
  alignas(64) double directStaticLanes[8];
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    _mm512_store_pd(
        baselineLanes,
        vectorRandom<false>(_mm512_loadu_pd(inputs.data() + offset)));
    _mm512_store_pd(
        candidateLanes,
        vectorRandom<true>(_mm512_loadu_pd(inputs.data() + offset)));
    _mm512_store_pd(
        staticLanes,
        vectorRandomStatic(_mm512_loadu_pd(inputs.data() + offset)));
    _mm512_store_pd(
        directStaticLanes,
        vectorRandomDirectStatic(_mm512_loadu_pd(inputs.data() + offset)));
    for (int lane = 0; lane < 8; ++lane) {
      if (std::bit_cast<std::uint64_t>(baselineLanes[lane])
              != std::bit_cast<std::uint64_t>(candidateLanes[lane])
          || std::bit_cast<std::uint64_t>(baselineLanes[lane])
              != std::bit_cast<std::uint64_t>(staticLanes[lane])
          || std::bit_cast<std::uint64_t>(baselineLanes[lane])
              != std::bit_cast<std::uint64_t>(directStaticLanes[lane])) {
        std::cerr << "mismatch offset=" << offset + lane << '\n';
        return 1;
      }
    }
  }
  std::cout << "verification=exact samples=" << inputs.size() << '\n';

  std::vector<double> baselineTimes;
  std::vector<double> ternaryTimes;
  std::vector<double> staticTimes;
  std::vector<double> directStaticTimes;
  std::uint64_t checksum = 0;
  std::uint64_t mutation = 0;
  const auto perturb = [&](int repeat) {
    const std::size_t index = static_cast<std::size_t>(
        (mutation++ * 1315423911ull + static_cast<unsigned>(repeat)))
        & (inputs.size() - 1);
    std::uint64_t bits = std::bit_cast<std::uint64_t>(inputs[index]);
    bits ^= 1;
    inputs[index] = std::bit_cast<double>(bits);
  };
  for (int pair = 0; pair < 9; ++pair) {
    if ((pair & 1) == 0) {
      baselineTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runBaseline(inputs);
          }, checksum));
      ternaryTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runTernary(inputs);
          }, checksum));
      staticTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runStatic(inputs);
          }, checksum));
      directStaticTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runDirectStatic(inputs);
          }, checksum));
    } else {
      directStaticTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runDirectStatic(inputs);
          }, checksum));
      staticTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runStatic(inputs);
          }, checksum));
      ternaryTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runTernary(inputs);
          }, checksum));
      baselineTimes.push_back(benchmark(
          [&](int repeat) {
            perturb(repeat);
            return runBaseline(inputs);
          }, checksum));
    }
  }
  const double baseline = median(baselineTimes);
  const double ternary = median(ternaryTimes);
  const double staticJump = median(staticTimes);
  const double directStatic = median(directStaticTimes);
  const double evaluations = static_cast<double>(sampleCount) * repeats;
  std::cout << std::fixed << std::setprecision(6)
            << "baseline_seconds=" << baseline
            << " baseline_Mstates_per_s="
            << evaluations / baseline / 1.0e6 << '\n'
            << "ternary_seconds=" << ternary
            << " ternary_Mstates_per_s="
            << evaluations / ternary / 1.0e6 << '\n'
            << "speedup=" << baseline / ternary << "x\n"
            << "static_seconds=" << staticJump
            << " static_Mstates_per_s="
            << evaluations / staticJump / 1.0e6 << '\n'
            << "static_speedup=" << baseline / staticJump << "x\n"
            << "direct_static_seconds=" << directStatic
            << " direct_static_Mstates_per_s="
            << evaluations / directStatic / 1.0e6 << '\n'
            << "direct_static_speedup=" << baseline / directStatic << "x\n"
            << "checksum=" << checksum << '\n';
  return 0;
}
