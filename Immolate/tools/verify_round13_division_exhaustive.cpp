#include <algorithm>
#include <atomic>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <immintrin.h>
#include <iostream>
#include <thread>
#include <vector>

namespace {

constexpr std::uint64_t maximumNumerator = 10000000000000ull;
constexpr double precision = 10000000000000.0;
constexpr double reciprocal = 1.0 / precision;

struct Result {
  std::uint64_t checked = 0;
  std::uint64_t mismatches = 0;
  std::uint64_t firstMismatch = 0;
};

Result verifyRange(std::uint64_t begin, std::uint64_t end) {
  Result result;
  const __m512d precisionVector = _mm512_set1_pd(precision);
  const __m512d reciprocalVector = _mm512_set1_pd(reciprocal);
  alignas(64) std::uint64_t expectedBits[8];
  alignas(64) std::uint64_t actualBits[8];
  std::uint64_t numerator = begin;
  for (; numerator + 8 <= end; numerator += 8) {
    const __m512i integers = _mm512_set_epi64(
        static_cast<long long>(numerator + 7),
        static_cast<long long>(numerator + 6),
        static_cast<long long>(numerator + 5),
        static_cast<long long>(numerator + 4),
        static_cast<long long>(numerator + 3),
        static_cast<long long>(numerator + 2),
        static_cast<long long>(numerator + 1),
        static_cast<long long>(numerator));
    const __m512d values = _mm512_cvtepi64_pd(integers);
    const __m512d expected = _mm512_div_pd(values, precisionVector);
    const __m512d quotient = _mm512_mul_pd(values, reciprocalVector);
    const __m512d residual =
        _mm512_fnmadd_pd(quotient, precisionVector, values);
    const __m512d actual =
        _mm512_fmadd_pd(residual, reciprocalVector, quotient);
    const __mmask8 mismatch = _mm512_cmpneq_pd_mask(expected, actual);
    if (mismatch != 0) {
      _mm512_store_si512(expectedBits, _mm512_castpd_si512(expected));
      _mm512_store_si512(actualBits, _mm512_castpd_si512(actual));
      for (int lane = 0; lane < 8; ++lane) {
        if ((mismatch & (1u << lane)) == 0) continue;
        ++result.mismatches;
        const std::uint64_t current = numerator + static_cast<unsigned>(lane);
        if (result.firstMismatch == 0) result.firstMismatch = current;
      }
    }
  }
  for (; numerator < end; ++numerator) {
    const double value = static_cast<double>(numerator);
    const double expected = value / precision;
    const double quotient = value * reciprocal;
    const double residual = std::fma(-quotient, precision, value);
    const double actual = std::fma(residual, reciprocal, quotient);
    if (std::bit_cast<std::uint64_t>(expected)
        != std::bit_cast<std::uint64_t>(actual)) {
      ++result.mismatches;
      if (result.firstMismatch == 0) result.firstMismatch = numerator;
    }
  }
  result.checked = end - begin;
  return result;
}

} // namespace

int main(int argc, char** argv) {
  const std::uint64_t requestedMaximum = argc > 1
      ? std::strtoull(argv[1], nullptr, 10)
      : maximumNumerator;
  const std::uint64_t inclusiveMaximum =
      requestedMaximum > maximumNumerator ? maximumNumerator : requestedMaximum;
  unsigned int threadCount = argc > 2
      ? static_cast<unsigned int>(std::strtoul(argv[2], nullptr, 10))
      : std::thread::hardware_concurrency();
  if (threadCount == 0) threadCount = 1;
  const std::uint64_t total = inclusiveMaximum + 1;
  threadCount = static_cast<unsigned int>(
      std::min<std::uint64_t>(threadCount, total));
  std::vector<Result> results(threadCount);
  std::vector<std::thread> workers;
  workers.reserve(threadCount);
  const auto started = std::chrono::steady_clock::now();
  for (unsigned int thread = 0; thread < threadCount; ++thread) {
    const std::uint64_t begin = total * thread / threadCount;
    const std::uint64_t end = total * (thread + 1) / threadCount;
    workers.emplace_back([&, thread, begin, end] {
      results[thread] = verifyRange(begin, end);
    });
  }
  for (std::thread& worker : workers) worker.join();
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  Result combined;
  for (const Result& result : results) {
    combined.checked += result.checked;
    combined.mismatches += result.mismatches;
    if (result.mismatches != 0
        && (combined.firstMismatch == 0
            || result.firstMismatch < combined.firstMismatch)) {
      combined.firstMismatch = result.firstMismatch;
    }
  }
  std::cout << "checked=" << combined.checked
            << " mismatches=" << combined.mismatches
            << " first_mismatch=" << combined.firstMismatch
            << " threads=" << threadCount
            << " seconds=" << std::fixed << std::setprecision(6) << seconds
            << " billion_values_per_second=" << std::setprecision(3)
            << static_cast<double>(combined.checked) / seconds / 1.0e9
            << '\n';
  return combined.mismatches == 0 ? 0 : 1;
}
