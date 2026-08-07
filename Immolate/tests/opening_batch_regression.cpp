#include "functions.hpp"
#include "opening_batch.hpp"
#include "seed.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

std::vector<std::uint32_t> simulatorReference(long long startSeedId,
                                              std::size_t count,
                                              OpeningCharmSoulCriteria criteria) {
  std::vector<std::uint32_t> survivors;
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    Instance instance(seed);
    instance.initLocks(1, false, true);
    if (instance.nextTag(1) == Item::Charm_Tag) {
      const ArcanaSoulPackResult pack =
          instance.scanArcanaPackForSoulJokers(
              5, 1, criteria.minimumSoulCount > 1);
      const bool identityMatches = criteria.legendaryIndex < 0
          || (!pack.soulJokers.empty()
              && pack.soulJokers[0].joker
                  == LEGENDARY_JOKERS[static_cast<std::size_t>(
                      criteria.legendaryIndex)]);
      if (pack.soulCount >= criteria.minimumSoulCount && identityMatches) {
        survivors.push_back(static_cast<std::uint32_t>(offset));
      }
    }
    seed.next();
  }
  return survivors;
}

bool compareBackend(long long startSeedId, std::size_t count,
                    OpeningCharmSoulCriteria criteria,
                    OpeningCharmSoulBackend backend,
                    const std::vector<std::uint32_t> &expected) {
  if (!openingCharmSoulBackendAvailable(backend)) {
    return true;
  }
  std::vector<std::uint32_t> actual;
  collectOpeningCharmSoulCandidatesWithBackend(
      startSeedId, count, actual, criteria, backend);
  if (actual == expected
      && std::is_sorted(actual.begin(), actual.end())) {
    return true;
  }
  std::cerr << "opening batch mismatch for backend "
            << openingCharmSoulBackendName(backend) << " at start "
            << startSeedId << ", expected " << expected.size()
            << " survivors, got " << actual.size()
            << ", souls=" << criteria.minimumSoulCount
            << ", legendary=" << criteria.legendaryIndex << std::endl;
  return false;
}

bool checkRange(long long startSeedId, std::size_t count,
                OpeningCharmSoulCriteria criteria) {
  const std::vector<std::uint32_t> expected =
      simulatorReference(startSeedId, count, criteria);
  bool passed = true;
  passed &= compareBackend(
      startSeedId, count, criteria,
      OpeningCharmSoulBackend::Scalar, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      OpeningCharmSoulBackend::Avx2, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      OpeningCharmSoulBackend::Avx512, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      OpeningCharmSoulBackend::Auto, expected);
  return passed;
}

std::vector<std::uint32_t> simulatorTagReference(
    long long startSeedId, std::size_t count, int targetTagIndex) {
  std::vector<std::uint32_t> survivors;
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    Instance instance(seed);
    instance.initLocks(1, false, true);
    if (instance.nextTag(1)
        == TAGS[static_cast<std::size_t>(targetTagIndex)]) {
      survivors.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
  return survivors;
}

bool compareTagBackend(long long startSeedId, std::size_t count,
                       int targetTagIndex,
                       OpeningCharmSoulBackend backend,
                       const std::vector<std::uint32_t> &expected) {
  if (!openingCharmSoulBackendAvailable(backend)) {
    return true;
  }
  std::vector<std::uint32_t> actual;
  collectOpeningTagCandidatesWithBackend(
      startSeedId, count, actual, OpeningTagCriteria{targetTagIndex},
      backend);
  if (actual == expected
      && std::is_sorted(actual.begin(), actual.end())) {
    return true;
  }
  std::cerr << "opening tag batch mismatch for backend "
            << openingCharmSoulBackendName(backend) << " at start "
            << startSeedId << ", expected " << expected.size()
            << " survivors, got " << actual.size()
            << ", tag index=" << targetTagIndex << std::endl;
  return false;
}

bool checkTagRange(long long startSeedId, std::size_t count,
                   int targetTagIndex) {
  const std::vector<std::uint32_t> expected = simulatorTagReference(
      startSeedId, count, targetTagIndex);
  bool passed = true;
  passed &= compareTagBackend(
      startSeedId, count, targetTagIndex,
      OpeningCharmSoulBackend::Scalar, expected);
  passed &= compareTagBackend(
      startSeedId, count, targetTagIndex,
      OpeningCharmSoulBackend::Avx2, expected);
  passed &= compareTagBackend(
      startSeedId, count, targetTagIndex,
      OpeningCharmSoulBackend::Avx512, expected);
  passed &= compareTagBackend(
      startSeedId, count, targetTagIndex,
      OpeningCharmSoulBackend::Auto, expected);
  return passed;
}

using InitialHashCollector = void (*)(
    void *, long long, std::size_t, std::vector<double> &,
    std::vector<double> &);
using DirectVectorCollector = void (*)(
    void *, long long, std::size_t, std::vector<std::uint32_t> &, bool);
using Round13Collector = void (*)(
    const std::vector<double> &, std::vector<double> &);

bool compareRound13Values(std::string_view backendName,
                          OpeningCharmSoulBackend backend,
                          Round13Collector collect,
                          const std::vector<double> &inputs,
                          std::string_view inputKind) {
  if (!openingCharmSoulBackendAvailable(backend)) {
    return true;
  }
  std::vector<double> outputs;
  collect(inputs, outputs);
  if (outputs.size() != inputs.size()) {
    std::cerr << backendName << " round13 " << inputKind
              << " output-size mismatch" << std::endl;
    return false;
  }
  for (std::size_t index = 0; index < inputs.size(); ++index) {
    const std::uint64_t expected =
        std::bit_cast<std::uint64_t>(round13(inputs[index]));
    const std::uint64_t actual =
        std::bit_cast<std::uint64_t>(outputs[index]);
    if (expected != actual) {
      std::cerr << backendName << " round13 " << inputKind
                << " mismatch at " << index << ", input bits="
                << std::bit_cast<std::uint64_t>(inputs[index])
                << ", expected=" << expected << ", actual=" << actual
                << std::endl;
      return false;
    }
  }
  return true;
}

void appendUnitNeighbors(std::vector<double> &inputs, double center,
                         int radius) {
  double below = center;
  for (int step = 0; step < radius; ++step) {
    below = std::nextafter(below, 0.0);
    if (below >= 0.0 && below < 1.0) {
      inputs.push_back(below);
    }
  }
  if (center >= 0.0 && center < 1.0) {
    inputs.push_back(center);
  }
  double above = center;
  for (int step = 0; step < radius; ++step) {
    above = std::nextafter(above, 1.0);
    if (above >= 0.0 && above < 1.0) {
      inputs.push_back(above);
    }
  }
}

std::vector<double> constructedRound13Inputs() {
  constexpr double precision = 10000000000000.0;
  std::vector<double> inputs = {
      0.0,
      std::numeric_limits<double>::denorm_min(),
      std::numeric_limits<double>::min(),
      std::nextafter(1.0, 0.0),
      std::bit_cast<double>(0x3d2c25c268497681ull),
      std::bit_cast<double>(0x3d2c25c268497682ull),
      std::bit_cast<double>(0x3fe00000000001c2ull),
      std::bit_cast<double>(0x3fe1f27a4285258bull),
      std::bit_cast<double>(0x3fef588e02d182e0ull),
      std::bit_cast<double>(0x3feffffffffffe3dull)};
  inputs.reserve(200000);

  std::uint64_t random = 0x726f756e643133ull;
  for (int sample = 0; sample < 4096; ++sample) {
    random ^= random << 13;
    random ^= random >> 7;
    random ^= random << 17;
    const double grid = static_cast<double>(
        random % 10000000000001ull) / precision;
    random ^= random << 13;
    random ^= random >> 7;
    random ^= random << 17;
    const double halfGrid =
        (static_cast<double>(random % 10000000000000ull) + 0.5)
        / precision;
    appendUnitNeighbors(inputs, grid, 8);
    appendUnitNeighbors(inputs, halfGrid, 8);
  }
  for (int exponent = 1; exponent <= 1074; ++exponent) {
    appendUnitNeighbors(inputs, std::ldexp(1.0, -exponent), 2);
  }
  for (int numerator = 0; numerator <= 8192; ++numerator) {
    appendUnitNeighbors(
        inputs, static_cast<double>(numerator) / 8192.0, 2);
  }
  return inputs;
}

std::vector<double> realOpeningRound13Inputs() {
  constexpr std::size_t seedCount = 1u << 19;
  constexpr double multiplier = 1.72431234;
  constexpr double addend = 2.134453429141;
  const std::string tagKey = "Tag1";
  const std::string soulKey = "soul_Tarot1";
  std::vector<double> inputs;
  inputs.reserve(seedCount * 6);
  Seed seed(1000000000000ll);
  for (std::size_t sample = 0; sample < seedCount; ++sample) {
    double tagState = pseudohash_from(
        tagKey, seed.pseudohash(static_cast<int>(tagKey.size())));
    inputs.push_back(fractPositive(tagState * multiplier + addend));

    double soulState = pseudohash_from(
        soulKey, seed.pseudohash(static_cast<int>(soulKey.size())));
    for (int card = 0; card < 5; ++card) {
      const double fraction =
          fractPositive(soulState * multiplier + addend);
      inputs.push_back(fraction);
      soulState = round13(fraction);
    }
    seed.next();
  }
  return inputs;
}

bool checkRound13VectorExactness() {
  const std::array<std::pair<std::uint64_t, std::uint64_t>, 9>
      fixedExpectations = {{
          {0x0000000000000000ull, 0x0000000000000000ull},
          {0x0000000000000001ull, 0x0000000000000000ull},
          {0x3d2c25c268497681ull, 0x0000000000000000ull},
          {0x3d2c25c268497682ull, 0x3d3c25c268497682ull},
          {0x3fe00000000001c2ull, 0x3fe0000000000000ull},
          {0x3fe1f27a4285258bull, 0x3fe1f27a4285274dull},
          {0x3fef588e02d182e0ull, 0x3fef588e02d1811eull},
          {0x3feffffffffffe3dull, 0x3feffffffffffc7bull},
          {0x3fefffffffffffffull, 0x3ff0000000000000ull}}};
  for (const auto &[inputBits, expectedBits] : fixedExpectations) {
    const double input = std::bit_cast<double>(inputBits);
    if (std::bit_cast<std::uint64_t>(round13(input)) != expectedBits) {
      std::cerr << "round13 fixed boundary reference changed for input "
                << inputBits << std::endl;
      return false;
    }
  }

  const std::vector<double> constructed = constructedRound13Inputs();
  const std::vector<double> realOpening = realOpeningRound13Inputs();
  bool passed = true;
#if defined(BRAINSTORM_OPENING_BATCH_AVX2)
  passed &= compareRound13Values(
      "avx2", OpeningCharmSoulBackend::Avx2,
      round13PositiveAvx2ForTesting, constructed, "constructed inputs");
  passed &= compareRound13Values(
      "avx2", OpeningCharmSoulBackend::Avx2,
      round13PositiveAvx2ForTesting, realOpening, "real opening lanes");
#endif
#if defined(BRAINSTORM_OPENING_BATCH_AVX512)
  passed &= compareRound13Values(
      "avx512", OpeningCharmSoulBackend::Avx512,
      round13PositiveAvx512ForTesting, constructed, "constructed inputs");
  passed &= compareRound13Values(
      "avx512", OpeningCharmSoulBackend::Avx512,
      round13PositiveAvx512ForTesting, realOpening, "real opening lanes");
#endif
  if (passed) {
    std::cout << "round13 vector exactness: " << constructed.size()
              << " constructed values and " << realOpening.size()
              << " real opening lanes per backend" << std::endl;
  }
  return passed;
}

bool compareIntermediateHashes(std::string_view backendName,
                               OpeningCharmSoulBackend backend,
                               InitialHashCollector collect,
                               long long startSeedId,
                               std::size_t count) {
  if (!openingCharmSoulBackendAvailable(backend)) {
    return true;
  }
  void *context = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria({1, -1}));
  std::vector<double> hashedSeeds;
  std::vector<double> tagSeedHashes;
  collect(context, startSeedId, count, hashedSeeds, tagSeedHashes);
  destroyOpeningCharmSoulBatchContext(context);
  if (hashedSeeds.size() != count || tagSeedHashes.size() != count) {
    std::cerr << backendName << " intermediate output-size mismatch at start "
              << startSeedId << std::endl;
    return false;
  }

  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    const std::uint64_t expectedHashed =
        std::bit_cast<std::uint64_t>(seed.pseudohash(0));
    const std::uint64_t expectedTag =
        std::bit_cast<std::uint64_t>(seed.pseudohash(4));
    const std::uint64_t actualHashed =
        std::bit_cast<std::uint64_t>(hashedSeeds[offset]);
    const std::uint64_t actualTag =
        std::bit_cast<std::uint64_t>(tagSeedHashes[offset]);
    if (expectedHashed != actualHashed || expectedTag != actualTag) {
      std::cerr << backendName << " intermediate mismatch at start "
                << startSeedId << ", offset " << offset
                << ", hashed expected=" << expectedHashed
                << ", actual=" << actualHashed
                << ", Tag1 expected=" << expectedTag
                << ", actual=" << actualTag << std::endl;
      return false;
    }
    seed.next();
  }
  return true;
}

bool compareSharedAndBaseline(std::string_view backendName,
                              OpeningCharmSoulBackend backend,
                              DirectVectorCollector collect,
                              long long startSeedId, std::size_t count,
                              OpeningCharmSoulCriteria criteria) {
  if (!openingCharmSoulBackendAvailable(backend)) {
    return true;
  }
  void *context = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria(criteria));
  std::vector<std::uint32_t> baseline;
  std::vector<std::uint32_t> shared;
  collect(context, startSeedId, count, baseline, false);
  collect(context, startSeedId, count, shared, true);
  destroyOpeningCharmSoulBatchContext(context);
  if (baseline == shared && std::is_sorted(shared.begin(), shared.end())) {
    return true;
  }
  std::cerr << backendName << " shared-prefix final mismatch at start "
            << startSeedId << ", count=" << count
            << ", baseline survivors=" << baseline.size()
            << ", shared survivors=" << shared.size() << std::endl;
  return false;
}

bool checkSharedPrefixInternals() {
  bool passed = true;
#if defined(BRAINSTORM_OPENING_BATCH_AVX2)
  for (const auto [start, count] :
       std::array<std::pair<long long, std::size_t>, 4>{
           std::pair{1000000000000ll, std::size_t{1u << 20}},
           std::pair{1000000000029ll, std::size_t{257}},
           std::pair{0ll, std::size_t{4353}},
           std::pair{SEED_DOMAIN_SIZE - 2048, std::size_t{4353}}}) {
    passed &= compareIntermediateHashes(
        "avx2", OpeningCharmSoulBackend::Avx2,
        collectOpeningCharmSoulInitialHashesAvx2ForTesting,
        start, count);
  }
  passed &= compareSharedAndBaseline(
      "avx2", OpeningCharmSoulBackend::Avx2,
      collectOpeningCharmSoulAvx2ForTesting,
      1000000000000ll + 13, 4353, {1, 4});
  passed &= compareSharedAndBaseline(
      "avx2", OpeningCharmSoulBackend::Avx2,
      collectOpeningCharmSoulAvx2ForTesting,
      SEED_DOMAIN_SIZE - 2048, 4353, {3, -1});
#endif
#if defined(BRAINSTORM_OPENING_BATCH_AVX512)
  for (const auto [start, count] :
       std::array<std::pair<long long, std::size_t>, 4>{
           std::pair{1000000000000ll, std::size_t{1u << 20}},
           std::pair{1000000000029ll, std::size_t{257}},
           std::pair{0ll, std::size_t{4353}},
           std::pair{SEED_DOMAIN_SIZE - 2048, std::size_t{4353}}}) {
    passed &= compareIntermediateHashes(
        "avx512", OpeningCharmSoulBackend::Avx512,
        collectOpeningCharmSoulInitialHashesAvx512ForTesting,
        start, count);
  }
  passed &= compareSharedAndBaseline(
      "avx512", OpeningCharmSoulBackend::Avx512,
      collectOpeningCharmSoulAvx512ForTesting,
      1000000000000ll + 13, 4353, {1, 4});
  passed &= compareSharedAndBaseline(
      "avx512", OpeningCharmSoulBackend::Avx512,
      collectOpeningCharmSoulAvx512ForTesting,
      SEED_DOMAIN_SIZE - 2048, 4353, {3, -1});
#endif
  return passed;
}

} // namespace

int main() {
  bool passed = true;
  passed &= checkRound13VectorExactness();
  passed &= checkSharedPrefixInternals();
  Seed oneHit("GPDJ3111");
  passed &= checkRange(
      oneHit.getID(), 1, OpeningCharmSoulCriteria{1, 4});
  passed &= checkRange(
      oneHit.getID() + 1, 1, OpeningCharmSoulCriteria{1, 4});
  for (int soulCount = 1; soulCount <= 4; ++soulCount) {
    passed &= checkRange(
        1000000000000ll, 1u << 18,
        OpeningCharmSoulCriteria{soulCount, -1});
  }
  for (int legendaryIndex = 0; legendaryIndex < 5; ++legendaryIndex) {
    passed &= checkRange(
        1000000000000ll, 1u << 18,
        OpeningCharmSoulCriteria{1, legendaryIndex});
  }
  // AVX-512 evaluates a requested Legendary identity before Tag/Soul.  Cover
  // every identity with the multi-Soul modes as well, including paths whose
  // expected survivor list is empty in this bounded range.
  for (int soulCount = 2; soulCount <= 4; ++soulCount) {
    for (int legendaryIndex = 0; legendaryIndex < 5;
         ++legendaryIndex) {
      passed &= checkRange(
          123456789012ll, 1u << 17,
          OpeningCharmSoulCriteria{soulCount, legendaryIndex});
    }
  }
  passed &= checkRange(0, 8192, OpeningCharmSoulCriteria{2, -1});
  passed &= checkRange(
      SEED_DOMAIN_SIZE - 4096, 8192,
      OpeningCharmSoulCriteria{3, -1});
  // Cross the domain boundary in the middle of a full vector chunk and leave
  // an awkward 257-seed tail for the outer chunking layer.
  passed &= checkRange(
      SEED_DOMAIN_SIZE - 2048, 4353,
      OpeningCharmSoulCriteria{1, 4});
  for (int tagIndex : std::array<int, 4>{0, 1, 10, 23}) {
    passed &= checkTagRange(
        1000000000000ll + 19, 8192, tagIndex);
  }
  passed &= checkTagRange(
      SEED_DOMAIN_SIZE - 2048, 4353, 10);
  if (passed) {
    std::cout << "Opening Soul and tag batches exact for scalar, AVX2, "
              << "AVX-512, and auto; "
              << "selected backend="
              << openingCharmSoulBackendName(
                     selectedOpeningCharmSoulBackend())
              << std::endl;
  }
  return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
