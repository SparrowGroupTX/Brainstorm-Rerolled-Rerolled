#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <random>
#include <vector>

namespace {

constexpr double precision = 10000000000000.0;
constexpr std::size_t sampleCount = 1u << 20;
constexpr int repeats = 64;

struct Reciprocal {
  double high;
  double low;
};

Reciprocal reciprocal() {
  const double high = 1.0 / precision;
  const long double exact = 1.0L / 10000000000000.0L;
  const double low = static_cast<double>(exact - static_cast<long double>(high));
  return {high, low};
}

template <int mode>
inline __m512d convert(__m512d numerator, const Reciprocal& value) {
  if constexpr (mode == 0) {
    return _mm512_div_pd(numerator, _mm512_set1_pd(precision));
  } else if constexpr (mode == 1) {
    return _mm512_mul_pd(numerator, _mm512_set1_pd(value.high));
  } else if constexpr (mode == 2) {
    const __m512d product =
        _mm512_mul_pd(numerator, _mm512_set1_pd(value.high));
    return _mm512_fmadd_pd(
        numerator, _mm512_set1_pd(value.low), product);
  } else {
    const __m512d reciprocalVector = _mm512_set1_pd(value.high);
    const __m512d quotient = _mm512_mul_pd(numerator, reciprocalVector);
    const __m512d residual = _mm512_fnmadd_pd(
        quotient, _mm512_set1_pd(precision), numerator);
    return _mm512_fmadd_pd(residual, reciprocalVector, quotient);
  }
}

template <int mode>
#if defined(__GNUC__)
__attribute__((noinline))
#endif
std::uint64_t run(const std::vector<double>& values,
                  const Reciprocal& reciprocalValue) {
  __m512i checksum = _mm512_setzero_si512();
  for (std::size_t offset = 0; offset < values.size(); offset += 8) {
    checksum = _mm512_xor_si512(
        checksum, _mm512_castpd_si512(convert<mode>(
                      _mm512_loadu_pd(values.data() + offset),
                      reciprocalValue)));
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
    inputs[index] = inputs[index] == precision ? 0.0 : inputs[index] + 1.0;
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
  const Reciprocal value = reciprocal();
  std::cout << std::hex << "high_bits=0x"
            << std::bit_cast<std::uint64_t>(value.high)
            << " low_bits=0x" << std::bit_cast<std::uint64_t>(value.low)
            << std::dec << '\n';

  std::mt19937_64 random(0x726f756e643133ull);
  std::vector<double> inputs(sampleCount);
  for (std::size_t index = 0; index < inputs.size(); ++index) {
    if (index < 262144) {
      inputs[index] = static_cast<double>(index);
    } else if (index < 524288) {
      inputs[index] = precision - static_cast<double>(index - 262144);
    } else {
      inputs[index] = static_cast<double>(random() % 10000000000001ull);
    }
  }

  std::uint64_t multiplyMismatch = 0;
  std::uint64_t doubleDoubleMismatch = 0;
  std::uint64_t residualMismatch = 0;
  std::uint64_t maximumUlpError = 0;
  alignas(64) double baseline[8], multiply[8], doubleDouble[8], residual[8];
  for (std::size_t offset = 0; offset < inputs.size(); offset += 8) {
    const __m512d source = _mm512_loadu_pd(inputs.data() + offset);
    _mm512_store_pd(baseline, convert<0>(source, value));
    _mm512_store_pd(multiply, convert<1>(source, value));
    _mm512_store_pd(doubleDouble, convert<2>(source, value));
    _mm512_store_pd(residual, convert<3>(source, value));
    for (int lane = 0; lane < 8; ++lane) {
      const std::uint64_t expected =
          std::bit_cast<std::uint64_t>(baseline[lane]);
      const std::uint64_t multiplied =
          std::bit_cast<std::uint64_t>(multiply[lane]);
      const std::uint64_t corrected =
          std::bit_cast<std::uint64_t>(doubleDouble[lane]);
      const std::uint64_t residualCorrected =
          std::bit_cast<std::uint64_t>(residual[lane]);
      multiplyMismatch += expected != multiplied;
      doubleDoubleMismatch += expected != corrected;
      residualMismatch += expected != residualCorrected;
      const std::uint64_t error = expected > corrected
          ? expected - corrected : corrected - expected;
      maximumUlpError = std::max(maximumUlpError, error);
    }
  }
  std::cout << "samples=" << inputs.size()
            << " multiply_mismatch=" << multiplyMismatch
            << " double_double_mismatch=" << doubleDoubleMismatch
            << " residual_mismatch=" << residualMismatch
            << " maximum_dd_ulp_error=" << maximumUlpError << '\n';

  std::vector<double> divideTimes, multiplyTimes, doubleDoubleTimes,
      residualTimes;
  std::uint64_t checksum = 0;
  std::uint64_t mutation = 0;
  for (int pair = 0; pair < 9; ++pair) {
    if ((pair & 1) == 0) {
      divideTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<0>(x, value); },
          checksum, mutation));
      multiplyTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<1>(x, value); },
          checksum, mutation));
      doubleDoubleTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<2>(x, value); },
          checksum, mutation));
      residualTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<3>(x, value); },
          checksum, mutation));
    } else {
      residualTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<3>(x, value); },
          checksum, mutation));
      doubleDoubleTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<2>(x, value); },
          checksum, mutation));
      multiplyTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<1>(x, value); },
          checksum, mutation));
      divideTimes.push_back(benchmark(
          inputs, [&](const auto& x) { return run<0>(x, value); },
          checksum, mutation));
    }
  }
  const double divide = median(divideTimes);
  const double multiplyTime = median(multiplyTimes);
  const double doubleDoubleTime = median(doubleDoubleTimes);
  const double residualTime = median(residualTimes);
  const double evaluations = static_cast<double>(sampleCount) * repeats;
  const auto print = [&](const char* name, double seconds) {
    std::cout << name << "_seconds=" << std::fixed << std::setprecision(6)
              << seconds << " Mvalues_per_s=" << std::setprecision(3)
              << evaluations / seconds / 1.0e6 << " speedup="
              << divide / seconds << "x\n";
  };
  print("divide", divide);
  print("multiply", multiplyTime);
  print("double_double", doubleDoubleTime);
  print("residual", residualTime);
  std::cout << "checksum=" << checksum << '\n';
}
