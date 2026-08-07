#include "opening_batch.hpp"
#include "seed.hpp"
#include "util.hpp"

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {
double initialTagRoll(Seed &seed) {
  const double hashedSeed = seed.pseudohash(0);
  double value = pseudohash_from("Tag1", seed.pseudohash(4));
  value = round13(fractPositive(value * 1.72431234 + 2.134453429141));
  return lua_random_from_seed((value + hashedSeed) * 0.5);
}
} // namespace

int main(int argc, char **argv) {
  if (argc > 1 && std::string(argv[1]) == "group") {
    const std::uint64_t firstGroup = argc > 2
        ? std::strtoull(argv[2], nullptr, 10) : 0;
    const std::size_t groupCount = argc > 3
        ? static_cast<std::size_t>(std::strtoull(argv[3], nullptr, 10))
        : 1000;
    const std::string groupOutput = argc > 4 ? argv[4] : std::string{};
    std::vector<std::uint8_t> categories(groupCount * 35);
    for (std::size_t groupOffset = 0; groupOffset < groupCount;
         ++groupOffset) {
      std::uint64_t rank = firstGroup + groupOffset;
      std::string internal(8, '1');
      // Rank groups in canonical-ID order: digit 0 is most significant and
      // digit 6 is least significant once the final 35-character run is
      // factored out.
      for (int position = 6; position >= 0; --position) {
        internal[static_cast<std::size_t>(position)] = seedChars[rank % 35];
        rank /= 35;
      }
      for (int last = 0; last < 35; ++last) {
        internal[7] = seedChars[last];
        const std::string text(internal.rbegin(), internal.rend());
        Seed seed(text);
        categories[groupOffset * 35 + static_cast<std::size_t>(last)] =
            static_cast<std::uint8_t>(initialTagRoll(seed) * 24.0);
      }
    }
    if (!groupOutput.empty()) {
      std::ofstream output(groupOutput, std::ios::binary | std::ios::trunc);
      output.write(reinterpret_cast<const char *>(categories.data()),
                   static_cast<std::streamsize>(categories.size()));
      if (!output) {
        std::cerr << "failed to write group-category fixture\n";
        return 2;
      }
    }
    std::size_t charm = 0;
    for (const std::uint8_t category : categories) {
      charm += category == 10;
    }
    std::cout << "first_group=" << firstGroup
              << " groups=" << groupCount
              << " seeds=" << categories.size()
              << " charm=" << charm << '\n';
    return 0;
  }

  if (argc > 1 && std::string(argv[1]) == "initial") {
    const long long initialStart = argc > 2
        ? std::strtoll(argv[2], nullptr, 10) : 0;
    const std::size_t initialCount = argc > 3
        ? static_cast<std::size_t>(std::strtoull(argv[3], nullptr, 10))
        : 1000000;
    const std::string initialOutput = argc > 4 ? argv[4] : std::string{};
    std::vector<std::uint8_t> categories(initialCount);
    Seed seed(normalizeSeedId(initialStart));
    for (std::size_t index = 0; index < initialCount; ++index) {
      categories[index] = static_cast<std::uint8_t>(
          initialTagRoll(seed) * 24.0);
      seed.next();
    }
    if (!initialOutput.empty()) {
      std::ofstream output(
          initialOutput, std::ios::binary | std::ios::trunc);
      output.write(reinterpret_cast<const char *>(categories.data()),
                   static_cast<std::streamsize>(categories.size()));
      if (!output) {
        std::cerr << "failed to write initial-category fixture\n";
        return 2;
      }
    }
    std::size_t charm = 0;
    for (const std::uint8_t category : categories) {
      charm += category == 10;
    }
    std::cout << "initial_start=" << initialStart
              << " count=" << initialCount << " charm=" << charm << '\n';
    return 0;
  }

  const long long start = argc > 1 ? std::strtoll(argv[1], nullptr, 10) : 0;
  const std::size_t count = argc > 2
      ? static_cast<std::size_t>(std::strtoull(argv[2], nullptr, 10))
      : 1000000;
  const std::string outputPath = argc > 3 ? argv[3] : std::string{};

  if (argc > 1 && std::string(argv[1]) == "one-char") {
    for (const char character : seedChars) {
      Seed seed(std::string(1, character));
      const int tag = static_cast<int>(initialTagRoll(seed) * 24.0);
      std::cout << character << ':' << tag << '\n';
    }
    return 0;
  }

  std::vector<std::uint32_t> survivors;
  collectOpeningTagCandidatesWithBackend(
      start, count, survivors, OpeningTagCriteria{10},
      OpeningCharmSoulBackend::Scalar);

  std::cout << "start=" << start << " count=" << count
            << " charm=" << survivors.size() << '\n';
  for (std::size_t index = 0; index < survivors.size() && index < 20; ++index) {
    Seed seed(normalizeSeedId(start + survivors[index]));
    std::cout << survivors[index] << ':' << seed.tostring() << '\n';
  }

  if (!outputPath.empty()) {
    std::vector<std::uint8_t> flags(count, 0);
    for (const std::uint32_t offset : survivors) {
      flags[offset] = 1;
    }
    std::ofstream output(outputPath, std::ios::binary | std::ios::trunc);
    output.write(reinterpret_cast<const char *>(flags.data()),
                 static_cast<std::streamsize>(flags.size()));
    if (!output) {
      std::cerr << "failed to write fixture\n";
      return 2;
    }
  }
  return 0;
}
