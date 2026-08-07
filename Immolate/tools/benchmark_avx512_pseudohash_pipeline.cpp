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

constexpr double hashA = 1.1239285023;
constexpr double hashPi = 3.141592653589793116;
constexpr std::size_t sampleCount = 1u << 20;
constexpr int repeats = 32;

template <int character, int position>
inline __m512d pseudostep(__m512d value) {
  __m512d next = _mm512_div_pd(_mm512_set1_pd(hashA), value);
  next = _mm512_mul_pd(next, _mm512_set1_pd(character));
  next = _mm512_mul_pd(next, _mm512_set1_pd(hashPi));
  next = _mm512_add_pd(next, _mm512_set1_pd(hashPi * position));
  return _mm512_sub_pd(
      next, _mm512_roundscale_pd(
                next, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC));
}

inline __m512d tag1(__m512d value) {
  value = pseudostep<'1', 4>(value);
  value = pseudostep<'g', 3>(value);
  value = pseudostep<'a', 2>(value);
  return pseudostep<'T', 1>(value);
}

#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runBaseline(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(
                      tag1(_mm512_loadu_pd(inputs.data() + offset))));
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) result ^= lane;
  return result;
}

template <int vectors>
#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t runPipelined(const std::vector<double>& inputs) {
  __m512i checksum = _mm512_setzero_si512();
  constexpr std::size_t stride = static_cast<std::size_t>(vectors) * 8;
  for (std::size_t offset = 0; offset < inputs.size(); offset += stride) {
    __m512d values[vectors];
    for (int vector = 0; vector < vectors; ++vector) {
      values[vector] = _mm512_loadu_pd(inputs.data() + offset + vector * 8);
    }
    for (int vector = 0; vector < vectors; ++vector)
      values[vector] = pseudostep<'1', 4>(values[vector]);
    for (int vector = 0; vector < vectors; ++vector)
      values[vector] = pseudostep<'g', 3>(values[vector]);
    for (int vector = 0; vector < vectors; ++vector)
      values[vector] = pseudostep<'a', 2>(values[vector]);
    for (int vector = 0; vector < vectors; ++vector)
      values[vector] = pseudostep<'T', 1>(values[vector]);
    for (int vector = 0; vector < vectors; ++vector) {
      checksum = _mm512_xor_si512(checksum, _mm512_castpd_si512(values[vector]));
    }
  }
  alignas(64) std::uint64_t lanes[8];
  _mm512_store_si512(lanes, checksum);
  std::uint64_t result = 0;
  for (std::uint64_t lane : lanes) result ^= lane;
  return result;
}

template <class Function>
double benchmark(std::vector<double>& inputs, Function function,
                 std::uint64_t& checksum, std::uint64_t& mutation) {
  const auto started = std::chrono::steady_clock::now();
  for (int repeat = 0; repeat < repeats; ++repeat) {
    const std::size_t index = static_cast<std::size_t>(
        mutation++ * 1315423911ull + static_cast<unsigned>(repeat))
        & (inputs.size() - 1);
    std::uint64_t bits = std::bit_cast<std::uint64_t>(inputs[index]);
    inputs[index] = std::bit_cast<double>(bits ^ 1);
    checksum ^= function(inputs) + static_cast<std::uint64_t>(repeat);
  }
  return std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
}

double median(std::vector<double> values) {
  std::sort(values.begin(), values.end());
  return values[values.size() / 2];
}

} // namespace

int main() {
  std::mt19937_64 random(0x6861736850697065ull);
  std::vector<double> inputs(sampleCount);
  for (double& input : inputs) {
    input = 0.05 + 0.95 * static_cast<double>(random() >> 11)
        / static_cast<double>(std::uint64_t{1} << 53);
  }

  std::vector<double> baseline(inputs.size());
  std::vector<double> candidate(inputs.size());
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    _mm512_storeu_pd(baseline.data() + offset,
                     tag1(_mm512_loadu_pd(inputs.data() + offset)));
  }
  for (std::size_t offset = 0; offset < inputs.size(); offset += 32) {
    __m512d values[4];
    for (int vector = 0; vector < 4; ++vector)
      values[vector] = _mm512_loadu_pd(inputs.data() + offset + vector * 8);
    for (int vector = 0; vector < 4; ++vector)
      values[vector] = pseudostep<'1', 4>(values[vector]);
    for (int vector = 0; vector < 4; ++vector)
      values[vector] = pseudostep<'g', 3>(values[vector]);
    for (int vector = 0; vector < 4; ++vector)
      values[vector] = pseudostep<'a', 2>(values[vector]);
    for (int vector = 0; vector < 4; ++vector)
      values[vector] = pseudostep<'T', 1>(values[vector]);
    for (int vector = 0; vector < 4; ++vector)
      _mm512_storeu_pd(candidate.data() + offset + vector * 8, values[vector]);
  }
  for (std::size_t index = 0; index < inputs.size(); ++index) {
    if (std::bit_cast<std::uint64_t>(baseline[index])
        != std::bit_cast<std::uint64_t>(candidate[index])) {
      std::cerr << "mismatch index=" << index << '\n';
      return 1;
    }
  }
  std::cout << "verification=exact samples=" << inputs.size() << '\n';

  std::vector<double> baselineTimes, pipeline2Times, pipeline4Times,
      pipeline8Times;
  std::uint64_t checksum = 0;
  std::uint64_t mutation = 0;
  for (int pair = 0; pair < 9; ++pair) {
    if ((pair & 1) == 0) {
      baselineTimes.push_back(benchmark(inputs, runBaseline, checksum, mutation));
      pipeline2Times.push_back(benchmark(inputs, runPipelined<2>, checksum, mutation));
      pipeline4Times.push_back(benchmark(inputs, runPipelined<4>, checksum, mutation));
      pipeline8Times.push_back(benchmark(inputs, runPipelined<8>, checksum, mutation));
    } else {
      pipeline8Times.push_back(benchmark(inputs, runPipelined<8>, checksum, mutation));
      pipeline4Times.push_back(benchmark(inputs, runPipelined<4>, checksum, mutation));
      pipeline2Times.push_back(benchmark(inputs, runPipelined<2>, checksum, mutation));
      baselineTimes.push_back(benchmark(inputs, runBaseline, checksum, mutation));
    }
  }
  const double base = median(baselineTimes);
  const double p2 = median(pipeline2Times);
  const double p4 = median(pipeline4Times);
  const double p8 = median(pipeline8Times);
  const double evaluations = static_cast<double>(sampleCount) * repeats;
  const auto print = [&](const char* name, double seconds) {
    std::cout << name << "_seconds=" << std::fixed << std::setprecision(6)
              << seconds << " Mvalues_per_s=" << std::setprecision(3)
              << evaluations / seconds / 1.0e6 << " speedup="
              << base / seconds << "x\n";
  };
  print("baseline", base);
  print("pipeline2", p2);
  print("pipeline4", p4);
  print("pipeline8", p8);
  std::cout << "checksum=" << checksum << '\n';
}
