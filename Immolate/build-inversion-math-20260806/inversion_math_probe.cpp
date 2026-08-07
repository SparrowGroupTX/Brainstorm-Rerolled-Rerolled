#include "../src/items.hpp"
#include "../src/opening_batch.hpp"
#include "../src/seed.hpp"
#include "../src/util.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <string>
#include <string_view>
#include <tuple>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

constexpr double kHashA = 1.1239285023;
constexpr double kHashPi = 3.141592653589793116;
constexpr double kLuaPi = 3.14159265358979323846;
constexpr double kLuaE = 2.7182818284590452354;
constexpr double kNodeMultiplier = 1.72431234;
constexpr double kNodeAddend = 2.134453429141;
constexpr std::uint64_t kDecimalGrid = 10000000000000ull;
constexpr std::uint64_t kNodeMultiplierNumerator = 172431234ull;
constexpr std::uint64_t kNodeMultiplierDenominator = 100000000ull;
constexpr std::uint64_t kNodeAddendGrid = 21344534291410ull;
constexpr std::uint64_t kMantissaMask = (std::uint64_t{1} << 52) - 1;

struct OpeningResult {
  int firstTag = -1;
  int acceptedTag = -1;
  int resamples = 0;
  std::uint8_t soulMask = 0;
  int legendary = -1;
};

bool isLockedTag(int tag) {
  switch (tag) {
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

double advanceNode(double value) {
  return round13(fractPositive(value * kNodeMultiplier + kNodeAddend));
}

double freshNode(Seed &seed, double hashedSeed, std::string_view key) {
  const std::string owned(key);
  double value = pseudohash_from(
      owned, seed.pseudohash(static_cast<int>(owned.size())));
  value = advanceNode(value);
  return (value + hashedSeed) * 0.5;
}

OpeningResult evaluateOpening(long long id) {
  Seed seed(id);
  OpeningResult result;
  const double hashedSeed = seed.pseudohash(0);
  for (int resample = 1; resample <= 1000; ++resample) {
    std::string key = "Tag1";
    if (resample > 1) {
      key += "_resample" + std::to_string(resample);
    }
    const int tag = lua_randint_from_seed(
        freshNode(seed, hashedSeed, key), 0, 23);
    if (resample == 1) {
      result.firstTag = tag;
    }
    result.resamples = resample;
    if (!isLockedTag(tag) || resample == 1000) {
      result.acceptedTag = tag;
      break;
    }
  }

  double soulState = pseudohash_from(
      "soul_Tarot1", seed.pseudohash(11));
  for (int card = 0; card < 5; ++card) {
    soulState = advanceNode(soulState);
    if (lua_random_from_seed((soulState + hashedSeed) * 0.5) > 0.997) {
      result.soulMask |= static_cast<std::uint8_t>(1u << card);
    }
  }
  result.legendary = lua_randint_from_seed(
      freshNode(seed, hashedSeed, "Joker4"), 0, 4);
  return result;
}

std::uint64_t splitmix64(std::uint64_t &state) {
  std::uint64_t value = (state += 0x9e3779b97f4a7c15ull);
  value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9ull;
  value = (value ^ (value >> 27)) * 0x94d049bb133111ebull;
  return value ^ (value >> 31);
}

std::uint64_t jumpWord(std::uint64_t z, int recurrence) {
  constexpr std::uint64_t all = ~std::uint64_t{0};
  switch (recurrence) {
  case 0:
    return (((z << 31) ^ z) >> 45) ^ ((z & (all << 1)) << 18);
  case 1:
    return (((z << 19) ^ z) >> 30) ^ ((z & (all << 6)) << 28);
  case 2:
    return (((z << 24) ^ z) >> 48) ^ ((z & (all << 9)) << 7);
  default:
    return (((z << 21) ^ z) >> 39) ^ ((z & (all << 17)) << 8);
  }
}

std::uint64_t jump11Mantissa(std::uint64_t value, int recurrence) {
  for (int step = 0; step < 11; ++step) {
    value = jumpWord(value, recurrence);
  }
  return value & kMantissaMask;
}

int gf2Rank(std::vector<std::array<std::uint64_t, 4>> rows) {
  int rank = 0;
  for (int column = 255; column >= 0 && rank < static_cast<int>(rows.size());
       --column) {
    const int word = column / 64;
    const std::uint64_t bit = std::uint64_t{1} << (column % 64);
    int pivot = rank;
    while (pivot < static_cast<int>(rows.size())
           && (rows[pivot][word] & bit) == 0) {
      ++pivot;
    }
    if (pivot == static_cast<int>(rows.size())) {
      continue;
    }
    std::swap(rows[rank], rows[pivot]);
    for (int row = 0; row < static_cast<int>(rows.size()); ++row) {
      if (row != rank && (rows[row][word] & bit) != 0) {
        for (int w = 0; w < 4; ++w) {
          rows[row][w] ^= rows[rank][w];
        }
      }
    }
    ++rank;
  }
  return rank;
}

void printRngRank() {
  std::vector<std::array<std::uint64_t, 4>> combinedRows(52);
  std::array<int, 4> perWordRanks{};
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    std::vector<std::array<std::uint64_t, 4>> wordRows(52);
    for (int inputBit = 0; inputBit < 64; ++inputBit) {
      const std::uint64_t output = jump11Mantissa(
          std::uint64_t{1} << inputBit, recurrence);
      for (int outputBit = 0; outputBit < 52; ++outputBit) {
        if ((output & (std::uint64_t{1} << outputBit)) != 0) {
          wordRows[outputBit][recurrence] |=
              std::uint64_t{1} << inputBit;
          combinedRows[outputBit][recurrence] |=
              std::uint64_t{1} << inputBit;
        }
      }
    }
    perWordRanks[recurrence] = gf2Rank(std::move(wordRows));
  }
  std::cout << "rng_gf2 per_word_ranks=" << perWordRanks[0] << ','
            << perWordRanks[1] << ',' << perWordRanks[2] << ','
            << perWordRanks[3]
            << " combined_rank=" << gf2Rank(std::move(combinedRows))
            << " combined_nullity=" << (256 - 52) << '\n';
}

std::uint64_t exactDecimalNode(std::uint64_t n) {
  const unsigned __int128 product =
      static_cast<unsigned __int128>(n) * kNodeMultiplierNumerator;
  std::uint64_t quotient = static_cast<std::uint64_t>(
      product / kNodeMultiplierDenominator);
  const std::uint64_t remainder = static_cast<std::uint64_t>(
      product % kNodeMultiplierDenominator);
  if (remainder * 2 >= kNodeMultiplierDenominator) {
    ++quotient;
  }
  return (quotient + kNodeAddendGrid) % kDecimalGrid;
}

void probeDecimalNode(std::uint64_t samples) {
  std::uint64_t state = 0x2f6e2b1d4a3c7981ull;
  std::uint64_t mismatches = 0;
  std::uint64_t firstN = 0;
  std::uint64_t firstExpected = 0;
  std::uint64_t firstActual = 0;
  std::int64_t maxDifference = 0;
  for (std::uint64_t sample = 0; sample < samples; ++sample) {
    const std::uint64_t n = splitmix64(state) % kDecimalGrid;
    const double input = static_cast<double>(n) /
                         static_cast<double>(kDecimalGrid);
    const double output = advanceNode(input);
    const std::uint64_t actual = static_cast<std::uint64_t>(
        std::llround(output * static_cast<double>(kDecimalGrid)))
        % kDecimalGrid;
    const std::uint64_t expected = exactDecimalNode(n);
    if (actual != expected) {
      if (mismatches == 0) {
        firstN = n;
        firstExpected = expected;
        firstActual = actual;
      }
      ++mismatches;
      std::int64_t difference = static_cast<std::int64_t>(actual)
          - static_cast<std::int64_t>(expected);
      if (difference > static_cast<std::int64_t>(kDecimalGrid / 2)) {
        difference -= static_cast<std::int64_t>(kDecimalGrid);
      } else if (difference < -static_cast<std::int64_t>(kDecimalGrid / 2)) {
        difference += static_cast<std::int64_t>(kDecimalGrid);
      }
      maxDifference = std::max<std::int64_t>(
          std::llabs(difference), maxDifference);
    }
  }
  std::cout << "node_decimal samples=" << samples
            << " mismatches=" << mismatches
            << " mismatch_rate="
            << static_cast<double>(mismatches) / samples
            << " max_grid_difference=" << maxDifference;
  if (mismatches != 0) {
    std::cout << " first_n=" << firstN
              << " expected=" << firstExpected
              << " actual=" << firstActual;
  }
  std::cout << '\n';
}

unsigned __int128 ceilDivide(unsigned __int128 numerator,
                             unsigned __int128 denominator) {
  return (numerator + denominator - 1) / denominator;
}

std::vector<std::uint64_t> invertDecimalNode(std::uint64_t target) {
  std::vector<std::uint64_t> candidates;
  const std::uint64_t addend = kNodeAddendGrid % kDecimalGrid;
  const unsigned __int128 twiceP =
      static_cast<unsigned __int128>(2) * kNodeMultiplierNumerator;
  const std::uint64_t maximumRounded = static_cast<std::uint64_t>(
      (static_cast<unsigned __int128>(kDecimalGrid - 1)
           * kNodeMultiplierNumerator
       + kNodeMultiplierDenominator / 2)
      / kNodeMultiplierDenominator);

  // The binary implementation differs from the exact decimal affine map by
  // at most one grid point in the sampled domain. Search those neighboring
  // decimal targets, derive the at-most-one integer preimage per wrap, then
  // retain only bit-exact forward matches.
  for (int correction = -1; correction <= 1; ++correction) {
    const std::uint64_t adjusted = static_cast<std::uint64_t>(
        (static_cast<std::int64_t>(target) + correction
         + static_cast<std::int64_t>(kDecimalGrid))
        % static_cast<std::int64_t>(kDecimalGrid));
    const std::uint64_t residue =
        (adjusted + kDecimalGrid - addend) % kDecimalGrid;
    for (std::uint64_t rounded = residue; rounded <= maximumRounded;) {
      const unsigned __int128 lowerNumerator = rounded == 0
          ? 0
          : (static_cast<unsigned __int128>(2) * rounded - 1)
                * kNodeMultiplierDenominator;
      const unsigned __int128 upperNumerator =
          (static_cast<unsigned __int128>(2) * rounded + 1)
          * kNodeMultiplierDenominator;
      const std::uint64_t lower = static_cast<std::uint64_t>(
          ceilDivide(lowerNumerator, twiceP));
      const std::uint64_t upperExclusive = static_cast<std::uint64_t>(
          ceilDivide(upperNumerator, twiceP));
      for (std::uint64_t n = lower;
           n < upperExclusive && n < kDecimalGrid; ++n) {
        const double output = advanceNode(
            static_cast<double>(n) / static_cast<double>(kDecimalGrid));
        const std::uint64_t actual = static_cast<std::uint64_t>(
            std::llround(output * static_cast<double>(kDecimalGrid)))
            % kDecimalGrid;
        if (actual == target) {
          candidates.push_back(n);
        }
      }
      if (rounded > maximumRounded - kDecimalGrid) {
        break;
      }
      rounded += kDecimalGrid;
    }
  }
  std::sort(candidates.begin(), candidates.end());
  candidates.erase(std::unique(candidates.begin(), candidates.end()),
                   candidates.end());
  return candidates;
}

void verifyDecimalInverse(std::uint64_t samples) {
  std::uint64_t state = 0xf04ac39b187d265eull;
  std::uint64_t misses = 0;
  std::uint64_t totalPreimages = 0;
  std::uint64_t maximumPreimages = 0;
  for (std::uint64_t sample = 0; sample < samples; ++sample) {
    const std::uint64_t n = splitmix64(state) % kDecimalGrid;
    const double output = advanceNode(
        static_cast<double>(n) / static_cast<double>(kDecimalGrid));
    const std::uint64_t target = static_cast<std::uint64_t>(
        std::llround(output * static_cast<double>(kDecimalGrid)))
        % kDecimalGrid;
    const std::vector<std::uint64_t> preimages = invertDecimalNode(target);
    totalPreimages += preimages.size();
    maximumPreimages = std::max<std::uint64_t>(
        maximumPreimages, preimages.size());
    if (!std::binary_search(preimages.begin(), preimages.end(), n)) {
      if (misses < 5) {
        std::cerr << "node_inverse_miss n=" << n
                  << " target=" << target
                  << " candidates=" << preimages.size() << '\n';
      }
      ++misses;
    }
  }
  std::cout << "node_inverse samples=" << samples
            << " misses=" << misses
            << " mean_preimages="
            << static_cast<double>(totalPreimages) / samples
            << " max_preimages=" << maximumPreimages << '\n';
  if (misses != 0) {
    std::exit(3);
  }
}

struct HashPair {
  std::uint64_t first;
  std::uint64_t second;
  auto operator<=>(const HashPair &) const = default;
};

double hashStep(double value, unsigned char character, int position) {
  return fractPositive(kHashA / value * character * kHashPi
                       + kHashPi * position);
}

void probeHashHalfStates() {
  std::vector<std::pair<double, double>> states{{1.0, 1.0}};
  for (int depth = 0; depth < 4; ++depth) {
    std::vector<std::pair<double, double>> next;
    next.reserve(states.size() * seedChars.size());
    const int position0 = 8 - depth;
    const int position4 = 12 - depth;
    for (const auto &[h0, h4] : states) {
      for (unsigned char character : seedChars) {
        next.emplace_back(hashStep(h0, character, position0),
                          hashStep(h4, character, position4));
      }
    }
    states.swap(next);
    std::vector<std::uint64_t> h0Bits;
    std::vector<HashPair> pairBits;
    h0Bits.reserve(states.size());
    pairBits.reserve(states.size());
    double minimum = 1.0;
    for (const auto &[h0, h4] : states) {
      minimum = std::min({minimum, h0, h4});
      h0Bits.push_back(std::bit_cast<std::uint64_t>(h0));
      pairBits.push_back({std::bit_cast<std::uint64_t>(h0),
                          std::bit_cast<std::uint64_t>(h4)});
    }
    std::sort(h0Bits.begin(), h0Bits.end());
    std::sort(pairBits.begin(), pairBits.end());
    const auto h0Unique = std::unique(h0Bits.begin(), h0Bits.end());
    const auto pairUnique = std::unique(pairBits.begin(), pairBits.end());
    std::cout << "hash_half depth=" << depth + 1
              << " states=" << states.size()
              << " h0_collisions=" << (h0Bits.end() - h0Unique)
              << " pair_collisions=" << (pairBits.end() - pairUnique)
              << " minimum_state=" << std::setprecision(17) << minimum
              << '\n';
  }

  double minH0 = 1.0;
  double maxH0 = 0.0;
  double minH4 = 1.0;
  double maxH4 = 0.0;
  for (const auto &[h0, h4] : states) {
    minH0 = std::min(minH0, h0);
    maxH0 = std::max(maxH0, h0);
    minH4 = std::min(minH4, h4);
    maxH4 = std::max(maxH4, h4);
  }
  const auto printBranches = [](std::string_view label, double minimum,
                                double maximum, double position) {
    constexpr double target = 0.5;
    std::uint64_t totalBranches = 0;
    std::uint64_t minBranches = std::numeric_limits<std::uint64_t>::max();
    std::uint64_t maxBranches = 0;
    for (unsigned char character : seedChars) {
      const double c = kHashA * static_cast<double>(character) * kHashPi;
      const double b = kHashPi * position;
      const long double low = static_cast<long double>(c) / maximum
          - target + b;
      const long double high = static_cast<long double>(c) / minimum
          - target + b;
      const auto first = static_cast<std::int64_t>(std::ceil(low));
      const auto last = static_cast<std::int64_t>(std::floor(high));
      const std::uint64_t branches = last >= first
          ? static_cast<std::uint64_t>(last - first + 1)
          : 0;
      totalBranches += branches;
      minBranches = std::min(minBranches, branches);
      maxBranches = std::max(maxBranches, branches);
    }
    std::cout << "real_inverse_one_step stream=" << label
              << " reachable_middle_min=" << std::setprecision(17)
              << minimum << " reachable_middle_max=" << maximum
              << " branches_across_35_chars=" << totalBranches
              << " min_per_char=" << minBranches
              << " max_per_char=" << maxBranches << '\n';
  };
  printBranches("H0", minH0, maxH0, 4.0);
  printBranches("H4", minH4, maxH4, 8.0);

  const long double tableEntries =
      static_cast<long double>(states.size()) * states.size();
  std::cout << "mitm_full_composition entries=" << std::fixed
            << std::setprecision(0) << tableEntries
            << " one_hash_TiB="
            << tableEntries * sizeof(double) / std::pow(1024.0L, 4)
            << " two_hash_TiB="
            << tableEntries * sizeof(HashPair) / std::pow(1024.0L, 4)
            << '\n';
}

std::uint64_t randomMantissa(double q) {
  double value = q;
  std::uint64_t result = 0;
  for (int recurrence = 0; recurrence < 4; ++recurrence) {
    value = value * kLuaPi + kLuaE;
    result ^= jump11Mantissa(std::bit_cast<std::uint64_t>(value), recurrence);
  }
  return result;
}

struct Fragmentation {
  std::uint64_t samples = 0;
  std::uint64_t distinctOutputs = 0;
  std::uint64_t exactHits = 0;
  std::uint64_t exactRuns = 0;
  std::uint64_t relevantHits = 0;
  std::uint64_t relevantRuns = 0;
  std::uint64_t outputPlateaus = 0;
  std::uint64_t soulHits = 0;
  std::uint64_t soulRuns = 0;
};

void addFragmentSample(Fragmentation &stats, std::uint64_t output,
                       std::uint64_t previous, bool havePrevious,
                       bool &previousExact, bool &previousRelevant,
                       bool &previousSoul) {
  const int tag = static_cast<int>(
      (static_cast<unsigned __int128>(output) * 24) >> 52);
  const bool exact = tag == 10;
  const bool relevant = exact || isLockedTag(tag);
  const bool soul = static_cast<double>(output)
      / static_cast<double>(std::uint64_t{1} << 52) > 0.997;
  ++stats.samples;
  stats.exactHits += exact;
  stats.relevantHits += relevant;
  stats.soulHits += soul;
  if (exact && (!havePrevious || !previousExact)) {
    ++stats.exactRuns;
  }
  if (relevant && (!havePrevious || !previousRelevant)) {
    ++stats.relevantRuns;
  }
  if (soul && (!havePrevious || !previousSoul)) {
    ++stats.soulRuns;
  }
  if (!havePrevious || output != previous) {
    ++stats.distinctOutputs;
  } else {
    ++stats.outputPlateaus;
  }
  previousExact = exact;
  previousRelevant = relevant;
  previousSoul = soul;
}

void printFragmentation(std::string_view label, const Fragmentation &stats) {
  std::cout << std::defaultfloat << std::setprecision(9)
            << "rng_fragmentation mode=" << label
            << " samples=" << stats.samples
            << " distinct_outputs=" << stats.distinctOutputs
            << " output_plateau_edges=" << stats.outputPlateaus
            << " charm_hits=" << stats.exactHits
            << " charm_runs=" << stats.exactRuns
            << " charm_mean_run="
            << static_cast<double>(stats.exactHits) / stats.exactRuns
            << " charm_runs_per_sample=" << std::scientific
            << static_cast<double>(stats.exactRuns) / stats.samples
            << " charm_or_lock_hits=" << stats.relevantHits
            << " charm_or_lock_runs=" << stats.relevantRuns
            << " relevant_mean_run=" << std::fixed
            << static_cast<double>(stats.relevantHits) / stats.relevantRuns
            << " soul_hits=" << stats.soulHits
            << " soul_runs=" << stats.soulRuns
            << " soul_mean_run="
            << static_cast<double>(stats.soulHits) / stats.soulRuns
            << '\n';
}

void probeRngFragmentation(std::uint64_t samples) {
  Fragmentation adjacent;
  double q = 0.5;
  std::uint64_t qBits = std::bit_cast<std::uint64_t>(q);
  std::uint64_t previous = 0;
  bool havePrevious = false;
  bool previousExact = false;
  bool previousRelevant = false;
  bool previousSoul = false;
  for (std::uint64_t index = 0; index < samples; ++index) {
    const std::uint64_t output = randomMantissa(
        std::bit_cast<double>(qBits + index));
    addFragmentSample(adjacent, output, previous, havePrevious,
                      previousExact, previousRelevant, previousSoul);
    previous = output;
    havePrevious = true;
  }
  printFragmentation("adjacent_doubles_at_0.5", adjacent);

  Fragmentation lattice;
  previous = 0;
  havePrevious = false;
  previousExact = false;
  previousRelevant = false;
  previousSoul = false;
  for (std::uint64_t index = 0; index < samples; ++index) {
    const double input = (static_cast<double>(index) + 0.5)
        / static_cast<double>(samples);
    const std::uint64_t output = randomMantissa(input);
    addFragmentSample(lattice, output, previous, havePrevious,
                      previousExact, previousRelevant, previousSoul);
    previous = output;
    havePrevious = true;
  }
  printFragmentation("uniform_lattice", lattice);

  Fragmentation decimalGrid;
  previous = 0;
  havePrevious = false;
  previousExact = false;
  previousRelevant = false;
  previousSoul = false;
  constexpr std::uint64_t gridStart = 2500000000000ull;
  for (std::uint64_t index = 0; index < samples; ++index) {
    const double input = static_cast<double>(gridStart + index)
        / static_cast<double>(kDecimalGrid);
    const std::uint64_t output = randomMantissa(input);
    addFragmentSample(decimalGrid, output, previous, havePrevious,
                      previousExact, previousRelevant, previousSoul);
    previous = output;
    havePrevious = true;
  }
  printFragmentation("adjacent_1e-13_grid", decimalGrid);

  Fragmentation actualSeeds;
  previous = 0;
  havePrevious = false;
  previousExact = false;
  previousRelevant = false;
  previousSoul = false;
  Seed seed(1000000000000ll);
  for (std::uint64_t index = 0; index < samples; ++index) {
    const double hashedSeed = seed.pseudohash(0);
    const double qInput = freshNode(seed, hashedSeed, "Tag1");
    const std::uint64_t output = randomMantissa(qInput);
    addFragmentSample(actualSeeds, output, previous, havePrevious,
                      previousExact, previousRelevant, previousSoul);
    previous = output;
    havePrevious = true;
    seed.next();
  }
  printFragmentation("sequential_seed_Tag1_inputs", actualSeeds);
}

void verifyManual(std::uint64_t samples) {
  std::uint64_t state = 0x6d2b79f5a4c3e187ull;
  std::uint64_t mismatches = 0;
  for (std::uint64_t sample = 0; sample < samples; ++sample) {
    const long long id = static_cast<long long>(
        splitmix64(state) % static_cast<std::uint64_t>(SEED_DOMAIN_SIZE));
    const OpeningResult manual = evaluateOpening(id);
    std::vector<std::uint32_t> result;
    collectOpeningCharmSoulCandidatesWithBackend(
        id, 1, result, OpeningCharmSoulCriteria{1, 4},
        OpeningCharmSoulBackend::Scalar);
    const bool expected = manual.acceptedTag == 10
        && manual.soulMask != 0 && manual.legendary == 4;
    const bool actual = !result.empty();
    if (actual != expected) {
      if (mismatches < 10) {
        std::cerr << "manual_mismatch id=" << id
                  << " seed=" << Seed(id).tostring()
                  << " expected=" << expected
                  << " actual=" << actual << '\n';
      }
      ++mismatches;
    }
  }
  std::cout << "manual_exactness samples=" << samples
            << " mismatches=" << mismatches << '\n';
  if (mismatches != 0) {
    std::exit(2);
  }
}

void printUsage(const char *program) {
  std::cerr << "usage: " << program
            << " [all|node|hash|rng|rank|verify] [samples]\n";
}

} // namespace

int main(int argc, char **argv) {
  const std::string mode = argc > 1 ? argv[1] : "all";
  const std::uint64_t samples = argc > 2
      ? std::strtoull(argv[2], nullptr, 10)
      : 1000000ull;
  const auto start = std::chrono::steady_clock::now();

  if (mode == "all" || mode == "verify") {
    verifyManual(std::min<std::uint64_t>(samples, 100000));
  }
  if (mode == "all" || mode == "rank") {
    printRngRank();
  }
  if (mode == "all" || mode == "node") {
    probeDecimalNode(samples);
    verifyDecimalInverse(std::min<std::uint64_t>(samples, 1000000));
  }
  if (mode == "all" || mode == "hash") {
    probeHashHalfStates();
  }
  if (mode == "all" || mode == "rng") {
    probeRngFragmentation(samples);
  }
  if (mode != "all" && mode != "verify" && mode != "rank"
      && mode != "node" && mode != "hash" && mode != "rng") {
    printUsage(argv[0]);
    return 1;
  }

  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - start).count();
  std::cout << "elapsed_seconds=" << std::fixed << std::setprecision(6)
            << seconds << '\n';
  return 0;
}
