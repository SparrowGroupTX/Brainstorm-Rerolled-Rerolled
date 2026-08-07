#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <random>
#include <vector>

namespace {

constexpr std::size_t SAMPLE_COUNT = 1u << 20;
constexpr int REPEATS = 16;
constexpr std::uint64_t DBL_MANT = 0x000fffffffffffffull;
constexpr std::uint64_t DBL_EXPO = 0x7ff0000000000000ull;
constexpr int DBL_MANT_SZ = 52;
constexpr int DBL_EXPO_BIAS = 1023;
constexpr double PRECISION = 10000000000000.0;

inline std::uint64_t bits(double value) {
  std::uint64_t result;
  std::memcpy(&result, &value, sizeof(result));
  return result;
}

inline double fromBits(std::uint64_t value) {
  double result;
  std::memcpy(&result, &value, sizeof(result));
  return result;
}

inline int portableClz(std::uint64_t value) {
#if defined(__GNUC__) || defined(__clang__)
  return value == 0 ? 64 : __builtin_clzll(value);
#else
  int result = 0;
  while ((value & (std::uint64_t{1} << 63u)) == 0) {
    value <<= 1u;
    ++result;
  }
  return result;
#endif
}

// Current production implementation, copied here so this benchmark remains
// diagnostic-only and cannot perturb the live mod.
inline double baselineFract(double x) {
  const std::uint64_t xInt = bits(x);
  const std::uint64_t exponent = (xInt & DBL_EXPO) >> DBL_MANT_SZ;
  if (exponent < DBL_EXPO_BIAS) {
    return x;
  }
  if (exponent == 0x7ffu) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  const std::uint64_t unbiased = exponent - DBL_EXPO_BIAS;
  if (unbiased >= DBL_MANT_SZ) {
    return 0;
  }
  const std::uint64_t mantissa = xInt & DBL_MANT;
  const std::uint64_t fractionalMantissa =
      mantissa & ((std::uint64_t{1} << (DBL_MANT_SZ - unbiased)) - 1);
  if (fractionalMantissa == 0) {
    return 0;
  }
  const std::uint64_t leadingZeros =
      portableClz(fractionalMantissa) - (64 - DBL_MANT_SZ);
  const std::uint64_t resultExponent =
      (exponent - leadingZeros - 1) << DBL_MANT_SZ;
  const std::uint64_t resultMantissa =
      (fractionalMantissa << (leadingZeros + 1)) & DBL_MANT;
  return fromBits(resultExponent | resultMantissa);
}

inline double floorFractPositive(double x) { return x - std::floor(x); }

inline double baselineRound13(double x) {
  const double normal = std::round(x * PRECISION) / PRECISION;
  if (normal ==
      (std::round(std::nextafter(x, -1.0) * PRECISION) / PRECISION)) {
    return normal;
  }
  constexpr double TWO_13 = 8192.0;
  constexpr double FIVE_13 = 1220703125.0;
  const double truncated = baselineFract(x * TWO_13) * FIVE_13;
  if (baselineFract(truncated) >= 0.5) {
    return (std::floor(x * PRECISION) + 1.0) / PRECISION;
  }
  return std::floor(x * PRECISION) / PRECISION;
}

inline double numeratorRound13(double x) {
  const double rounded = std::round(x * PRECISION);
  if (rounded == std::round(std::nextafter(x, -1.0) * PRECISION)) {
    return rounded / PRECISION;
  }
  constexpr double TWO_13 = 8192.0;
  constexpr double FIVE_13 = 1220703125.0;
  const double truncated = baselineFract(x * TWO_13) * FIVE_13;
  if (baselineFract(truncated) >= 0.5) {
    return (std::floor(x * PRECISION) + 1.0) / PRECISION;
  }
  return std::floor(x * PRECISION) / PRECISION;
}

inline double fastErraticStep(double node) {
  const double mixed = node * 1.72431234 + 2.134453429141;
  return numeratorRound13(floorFractPositive(mixed));
}

inline double numeratorOnlyErraticStep(double node) {
  const double mixed = node * 1.72431234 + 2.134453429141;
  return numeratorRound13(baselineFract(mixed));
}

inline double floorOnlyErraticStep(double node) {
  const double mixed = node * 1.72431234 + 2.134453429141;
  return baselineRound13(floorFractPositive(mixed));
}

inline double baselineErraticStep(double node) {
  const double mixed = node * 1.72431234 + 2.134453429141;
  return baselineRound13(baselineFract(mixed));
}

template <typename Function>
double benchmark(const std::vector<double> &inputs, Function function,
                 std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (double value : inputs) {
      local ^= bits(function(value));
      local = (local << 9u) | (local >> 55u);
    }
  }
  checksum ^= local;
  return std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      started)
      .count();
}

template <typename Function>
double benchmarkChains(const std::vector<double> &inputs, Function function,
                       std::uint64_t &checksum) {
  const auto started = std::chrono::steady_clock::now();
  std::uint64_t local = 0;
  for (int repeat = 0; repeat < REPEATS; ++repeat) {
    for (double value : inputs) {
      for (int card = 0; card < 52; ++card) {
        value = function(value);
      }
      local ^= bits(value);
      local = (local << 9u) | (local >> 55u);
    }
  }
  checksum ^= local;
  return std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      started)
      .count();
}

} // namespace

int main() {
  std::mt19937_64 random(0x45525241544943ull);
  std::vector<double> nodes(SAMPLE_COUNT);
  for (double &node : nodes) {
    node = std::generate_canonical<double, 53>(random);
  }

  // Exercise positive finite values across the entire exponent range. Sterbenz's
  // lemma predicts x-floor(x) is exact here, but the differential check is the
  // authority for this implementation.
  for (std::size_t i = 0; i < SAMPLE_COUNT; ++i) {
    const std::uint64_t exponent = random() % 0x7ffu;
    const std::uint64_t candidate =
        (exponent << DBL_MANT_SZ) | (random() & DBL_MANT);
    const double value = fromBits(candidate);
    if (bits(baselineFract(value)) != bits(floorFractPositive(value))) {
      std::cerr << "positive fract differential failure bits=0x" << std::hex
                << candidate << '\n';
      return 1;
    }
  }

  // Cover ordinary nodes, exact 1e-13 grid points, and both neighboring doubles
  // around grid/half-grid boundaries where round13 takes its slow correction.
  for (std::size_t i = 0; i < SAMPLE_COUNT; ++i) {
    double candidates[7];
    candidates[0] = nodes[i];
    const double grid = static_cast<double>(random() % 10000000000001ull) /
                        PRECISION;
    const double halfGrid =
        (static_cast<double>(random() % 10000000000000ull) + 0.5) /
        PRECISION;
    candidates[1] = grid;
    candidates[2] = std::nextafter(grid, 0.0);
    candidates[3] = std::nextafter(grid, 1.0);
    candidates[4] = halfGrid;
    candidates[5] = std::nextafter(halfGrid, 0.0);
    candidates[6] = std::nextafter(halfGrid, 1.0);
    for (double candidate : candidates) {
      if (bits(baselineRound13(candidate)) !=
          bits(numeratorRound13(candidate))) {
        std::cerr << "round13 differential failure input_bits=0x" << std::hex
                  << bits(candidate) << '\n';
        return 1;
      }
    }
    if (bits(baselineErraticStep(nodes[i])) !=
            bits(numeratorOnlyErraticStep(nodes[i])) ||
        bits(baselineErraticStep(nodes[i])) !=
            bits(floorOnlyErraticStep(nodes[i])) ||
        bits(baselineErraticStep(nodes[i])) != bits(fastErraticStep(nodes[i]))) {
      std::cerr << "erratic step differential failure index=" << i << '\n';
      return 1;
    }
    double baselineChain = nodes[i];
    double fastChain = nodes[i];
    for (int card = 0; card < 52; ++card) {
      baselineChain = baselineErraticStep(baselineChain);
      fastChain = fastErraticStep(fastChain);
    }
    if (bits(baselineChain) != bits(fastChain)) {
      std::cerr << "erratic chain differential failure index=" << i << '\n';
      return 1;
    }
  }

  std::uint64_t checksum = 0;
  const double baselineSeconds =
      benchmark(nodes, baselineErraticStep, checksum);
  const double numeratorSeconds =
      benchmark(nodes, numeratorOnlyErraticStep, checksum);
  const double floorOnlySeconds =
      benchmark(nodes, floorOnlyErraticStep, checksum);
  const double fastSeconds = benchmark(nodes, fastErraticStep, checksum);
  const double calls = static_cast<double>(SAMPLE_COUNT) * REPEATS;
  auto report = [calls, baselineSeconds](const char *name, double seconds) {
    std::cout << std::left << std::setw(15) << name << " seconds=" << std::fixed
              << std::setprecision(6) << seconds << " ns_per_step="
              << std::setprecision(2) << seconds * 1.0e9 / calls
              << " speedup=" << std::setprecision(3)
              << baselineSeconds / seconds << "x\n";
  };
  report("baseline", baselineSeconds);
  report("numerator", numeratorSeconds);
  report("floor_only", floorOnlySeconds);
  report("floor_fract", fastSeconds);

  const double baselineChainSeconds =
      benchmarkChains(nodes, baselineErraticStep, checksum);
  const double numeratorChainSeconds =
      benchmarkChains(nodes, numeratorOnlyErraticStep, checksum);
  const double floorOnlyChainSeconds =
      benchmarkChains(nodes, floorOnlyErraticStep, checksum);
  const double fastChainSeconds =
      benchmarkChains(nodes, fastErraticStep, checksum);
  const double chainCalls = calls * 52.0;
  auto reportChain = [chainCalls, baselineChainSeconds](const char *name,
                                                       double seconds) {
    std::cout << std::left << std::setw(15) << name << " seconds=" << std::fixed
              << std::setprecision(6) << seconds << " ns_per_step="
              << std::setprecision(2) << seconds * 1.0e9 / chainCalls
              << " speedup=" << std::setprecision(3)
              << baselineChainSeconds / seconds << "x\n";
  };
  reportChain("chain_baseline", baselineChainSeconds);
  reportChain("chain_numerator", numeratorChainSeconds);
  reportChain("chain_flooronly", floorOnlyChainSeconds);
  reportChain("chain_floor", fastChainSeconds);
  std::cout << "checksum=" << checksum << '\n';
  return 0;
}
