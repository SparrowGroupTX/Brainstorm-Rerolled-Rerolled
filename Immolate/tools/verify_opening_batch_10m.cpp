#include "opening_batch.hpp"
#include "seed.hpp"

#include <array>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <utility>
#include <vector>

namespace {

bool compareRange(long long start, std::size_t count,
                  OpeningCharmSoulCriteria criteria,
                  OpeningCharmSoulBackend backend,
                  std::uint64_t &verified) {
  std::vector<std::uint32_t> reference;
  std::vector<std::uint32_t> candidate;
  collectOpeningCharmSoulCandidatesWithBackend(
      start, count, reference, criteria, OpeningCharmSoulBackend::Scalar);
  collectOpeningCharmSoulCandidatesWithBackend(
      start, count, candidate, criteria, backend);
  if (reference != candidate) {
    std::cerr << "mismatch backend="
              << openingCharmSoulBackendName(backend)
              << " start=" << start << " count=" << count
              << " reference=" << reference.size()
              << " candidate=" << candidate.size() << '\n';
    return false;
  }
  verified += count;
  return true;
}

} // namespace

int main() {
  constexpr std::size_t rangeSize = 1u << 22;
  const std::array<std::pair<long long, std::size_t>, 3> ranges = {{
      {1000000000000ll + 17, rangeSize},
      {SEED_DOMAIN_SIZE - static_cast<long long>(rangeSize / 2), rangeSize},
      {0, rangeSize},
  }};
  bool passed = true;
  for (OpeningCharmSoulBackend backend : {
           OpeningCharmSoulBackend::Avx2,
           OpeningCharmSoulBackend::Avx512}) {
    if (!openingCharmSoulBackendAvailable(backend)) {
      continue;
    }
    std::uint64_t verified = 0;
    for (const auto &[start, count] : ranges) {
      passed &= compareRange(
          start, count, OpeningCharmSoulCriteria{1, 4}, backend, verified);
    }
    std::cout << openingCharmSoulBackendName(backend)
              << " exact differential seeds=" << verified << '\n';
  }
  return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
