#include "../src/functions.hpp"
#include "../src/opening_batch.hpp"
#include "../src/seed.hpp"
#include "../src/util.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <mutex>
#include <numeric>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <utility>
#include <vector>

// This is a disposable statistical diagnostic. It deliberately lives outside
// src/ and links against the unmodified native implementation. Opening-stage
// labels come from the exact production SIMD collectors; the sparse downstream
// labels are replayed through Instance, which is the scalar ground truth.

namespace {

constexpr int kCharmTagIndex = 10;
constexpr int kPerkeoIndex = 4;
constexpr std::size_t kChunkSize = 1u << 20;
constexpr std::size_t kHashSampleChunks = 8;
constexpr int kHashBuckets = 256;
constexpr int kResidueBuckets = 4096;
constexpr int kPairBuckets = 35 * 35;
constexpr int kTripleBuckets = 35 * 35 * 35;

enum Stage : int {
  Charm = 0,
  CharmSoul,
  CharmSoulJudgement,
  CharmSoulJudgementInvisible,
  CharmSoulTelescope,
  CharmSoulObservatory,
  CharmSoulPerkeo,
  PerkeoJudgement,
  PerkeoJudgementInvisible,
  PerkeoTelescope,
  PerkeoObservatory,
  PerkeoJudgementInvisibleTelescope,
  PerkeoJudgementInvisibleObservatory,
  StageCount,
};

constexpr std::array<const char *, StageCount> kStageNames = {
    "charm",
    "charm_soul",
    "charm_soul_judgement",
    "charm_soul_judgement_invisible",
    "charm_soul_telescope",
    "charm_soul_observatory",
    "charm_soul_perkeo",
    "perkeo_judgement",
    "perkeo_judgement_invisible",
    "perkeo_telescope",
    "perkeo_observatory",
    "perkeo_judgement_invisible_telescope",
    "perkeo_judgement_invisible_observatory",
};

constexpr std::array<int, 22> kLags = {
    1, 2, 3, 4, 5, 7, 8, 16, 31, 32, 34,
    35, 36, 64, 127, 128, 256, 1024, 1225, 4096, 8192, 42875};
constexpr std::array<int, 6> kBlockSizes = {
    35, 1225, 4096, 42875, 65536, 1048576};

struct FeatureCounts {
  std::array<std::array<std::uint64_t, 35>, 8> position{};
  std::array<std::uint64_t, kPairBuckets> prefix2{};
  std::array<std::uint64_t, kPairBuckets> suffix2{};
  std::array<std::uint64_t, kPairBuckets> outer2{};
  std::array<std::uint64_t, kTripleBuckets> prefix3{};
  std::array<std::uint64_t, kTripleBuckets> suffix3{};
  std::array<std::uint64_t, kResidueBuckets> residue{};
  std::array<std::uint64_t, kHashBuckets> seedHash{};
  std::array<std::uint64_t, kHashBuckets> tagSeedHash{};

  void add(const FeatureCounts &other) {
    for (std::size_t pos = 0; pos < position.size(); ++pos) {
      for (std::size_t ch = 0; ch < position[pos].size(); ++ch) {
        position[pos][ch] += other.position[pos][ch];
      }
    }
    auto addArray = [](auto &left, const auto &right) {
      for (std::size_t i = 0; i < left.size(); ++i) left[i] += right[i];
    };
    addArray(prefix2, other.prefix2);
    addArray(suffix2, other.suffix2);
    addArray(outer2, other.outer2);
    addArray(prefix3, other.prefix3);
    addArray(suffix3, other.suffix3);
    addArray(residue, other.residue);
    addArray(seedHash, other.seedHash);
    addArray(tagSeedHash, other.tagSeedHash);
  }
};

struct LagCounts {
  std::uint64_t pairs = 0;
  std::uint64_t both = 0;
};

struct BlockCounts {
  std::uint64_t blocks = 0;
  std::uint64_t zeroBlocks = 0;
  std::uint64_t sum = 0;
  long double sumSquares = 0;
  std::uint64_t maxHits = 0;
};

struct RangeStats {
  std::uint64_t seeds = 0;
  std::uint64_t fullLengthSeeds = 0;
  FeatureCounts denominators;
  std::array<FeatureCounts, StageCount> hitsByFeature;
  std::array<std::uint64_t, StageCount> stageHits{};
  std::array<std::array<LagCounts, kLags.size()>, StageCount> lags{};
  std::array<std::array<BlockCounts, kBlockSizes.size()>, StageCount> blocks{};
  std::array<std::vector<std::uint64_t>, StageCount> hitIds;

  void add(const RangeStats &other) {
    seeds += other.seeds;
    fullLengthSeeds += other.fullLengthSeeds;
    denominators.add(other.denominators);
    for (int stage = 0; stage < StageCount; ++stage) {
      hitsByFeature[stage].add(other.hitsByFeature[stage]);
      stageHits[stage] += other.stageHits[stage];
      for (std::size_t lag = 0; lag < kLags.size(); ++lag) {
        lags[stage][lag].pairs += other.lags[stage][lag].pairs;
        lags[stage][lag].both += other.lags[stage][lag].both;
      }
      for (std::size_t block = 0; block < kBlockSizes.size(); ++block) {
        auto &left = blocks[stage][block];
        const auto &right = other.blocks[stage][block];
        left.blocks += right.blocks;
        left.zeroBlocks += right.zeroBlocks;
        left.sum += right.sum;
        left.sumSquares += right.sumSquares;
        left.maxHits = std::max(left.maxHits, right.maxHits);
      }
      hitIds[stage].insert(hitIds[stage].end(),
                           other.hitIds[stage].begin(),
                           other.hitIds[stage].end());
    }
  }
};

struct Task {
  int rangeIndex = 0;
  std::uint64_t start = 0;
  std::uint64_t count = 0;
  bool collectHashes = false;
};

struct ExactFlags {
  bool judgement = false;
  bool judgementInvisible = false;
  bool perkeo = false;
  bool telescope = false;
  bool observatory = false;
};

int bucket01(double value) {
  int bucket = static_cast<int>(value * kHashBuckets);
  if (bucket < 0) bucket = 0;
  if (bucket >= kHashBuckets) bucket = kHashBuckets - 1;
  return bucket;
}

int digitAtDisplayPosition(const Seed &seed, int displayPosition) {
  return seed.seed[7 - displayPosition];
}

struct EncodedFeatures {
  std::array<int, 8> digits{};
  int prefix2 = 0;
  int suffix2 = 0;
  int outer2 = 0;
  int prefix3 = 0;
  int suffix3 = 0;
  int residue = 0;
};

EncodedFeatures encodeFeatures(const Seed &seed, std::uint64_t id) {
  EncodedFeatures result;
  for (int pos = 0; pos < 8; ++pos) {
    result.digits[pos] = digitAtDisplayPosition(seed, pos);
  }
  result.prefix2 = result.digits[0] * 35 + result.digits[1];
  result.suffix2 = result.digits[6] * 35 + result.digits[7];
  result.outer2 = result.digits[0] * 35 + result.digits[7];
  result.prefix3 = (result.digits[0] * 35 + result.digits[1]) * 35
                   + result.digits[2];
  result.suffix3 = (result.digits[5] * 35 + result.digits[6]) * 35
                   + result.digits[7];
  result.residue = static_cast<int>(id & (kResidueBuckets - 1));
  return result;
}

void addFeatures(FeatureCounts &counts, const EncodedFeatures &features,
                 bool includeCharacters) {
  if (includeCharacters) {
    for (int pos = 0; pos < 8; ++pos) {
      const int digit = features.digits[pos];
      if (digit >= 0 && digit < 35) counts.position[pos][digit]++;
    }
    counts.prefix2[features.prefix2]++;
    counts.suffix2[features.suffix2]++;
    counts.outer2[features.outer2]++;
    counts.prefix3[features.prefix3]++;
    counts.suffix3[features.suffix3]++;
  }
  counts.residue[features.residue]++;
}

ExactFlags classifyExact(std::uint64_t rawId) {
  Seed seed(static_cast<long long>(rawId));
  Instance instance(seed);
  instance.initLocks(1, false, true);
  ExactFlags result;

  if (instance.nextTag(1) != Item::Charm_Tag) return result;

  std::array<Item, 5> cards{};
  int soulCount = 0;
  for (int card = 0; card < 5; ++card) {
    const Item item = instance.nextTarot(ItemSource::Arcana_Pack, 1, true);
    cards[card] = item;
    if (item == Item::The_Soul) ++soulCount;
    if (item == Item::Judgement) result.judgement = true;
    if (!instance.params.showman) instance.lockTransient(item);
  }
  for (Item item : cards) instance.unlockTransient(item);
  if (soulCount == 0) return result;

  for (int soul = 0; soul < soulCount; ++soul) {
    const JokerData joker = instance.nextJoker(ItemSource::Soul, 1, false);
    if (soul == 0 && joker.joker == Item::Perkeo) result.perkeo = true;
    if (!instance.params.showman) instance.lock(joker.joker);
  }
  if (result.judgement) {
    const JokerData joker =
        instance.nextJoker(ItemSource::Judgement, 1, false);
    result.judgementInvisible = joker.joker == Item::Invisible_Joker;
    if (!instance.params.showman) instance.lock(joker.joker);
  }

  const Item firstVoucher = instance.nextVoucher(1);
  result.telescope = firstVoucher == Item::Telescope;
  if (result.telescope) {
    instance.activateVoucher(Item::Telescope);
    result.observatory = instance.nextVoucher(2) == Item::Observatory;
  }
  return result;
}

void setExactStages(std::array<std::uint8_t, StageCount> &flags,
                    const ExactFlags &exact) {
  flags[CharmSoulJudgement] = exact.judgement;
  flags[CharmSoulJudgementInvisible] = exact.judgementInvisible;
  flags[CharmSoulTelescope] = exact.telescope;
  flags[CharmSoulObservatory] = exact.observatory;
  flags[CharmSoulPerkeo] = exact.perkeo;
  flags[PerkeoJudgement] = exact.perkeo && exact.judgement;
  flags[PerkeoJudgementInvisible] =
      exact.perkeo && exact.judgementInvisible;
  flags[PerkeoTelescope] = exact.perkeo && exact.telescope;
  flags[PerkeoObservatory] = exact.perkeo && exact.observatory;
  flags[PerkeoJudgementInvisibleTelescope] =
      exact.perkeo && exact.judgementInvisible && exact.telescope;
  flags[PerkeoJudgementInvisibleObservatory] =
      exact.perkeo && exact.judgementInvisible && exact.observatory;
}

void updateLagAndBlockStats(
    RangeStats &stats,
    const std::array<std::vector<std::uint8_t>, StageCount> &flags) {
  const std::size_t count = flags[0].size();
  for (int stage = 0; stage < StageCount; ++stage) {
    for (std::size_t lagIndex = 0; lagIndex < kLags.size(); ++lagIndex) {
      const std::size_t lag = static_cast<std::size_t>(kLags[lagIndex]);
      if (lag >= count) continue;
      auto &out = stats.lags[stage][lagIndex];
      out.pairs += count - lag;
      for (std::size_t i = lag; i < count; ++i) {
        out.both += static_cast<std::uint64_t>(
            flags[stage][i] && flags[stage][i - lag]);
      }
    }
    for (std::size_t blockIndex = 0; blockIndex < kBlockSizes.size();
         ++blockIndex) {
      const std::size_t blockSize =
          static_cast<std::size_t>(kBlockSizes[blockIndex]);
      auto &out = stats.blocks[stage][blockIndex];
      for (std::size_t begin = 0; begin + blockSize <= count;
           begin += blockSize) {
        std::uint64_t blockHits = 0;
        for (std::size_t i = begin; i < begin + blockSize; ++i) {
          blockHits += flags[stage][i];
        }
        out.blocks++;
        out.zeroBlocks += blockHits == 0;
        out.sum += blockHits;
        out.sumSquares += static_cast<long double>(blockHits) * blockHits;
        out.maxHits = std::max(out.maxHits, blockHits);
      }
    }
  }
}

void markOffsets(std::vector<std::uint8_t> &flags,
                 const std::vector<std::uint32_t> &offsets) {
  for (std::uint32_t offset : offsets) flags[offset] = 1;
}

void processTask(const Task &task, RangeStats &stats) {
  void *tagContext = createOpeningTagBatchContext(
      encodeOpeningTagCriteria({kCharmTagIndex}));
  void *soulContext = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria({1, -1}));
  void *perkeoContext = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria({1, kPerkeoIndex}));

  std::vector<std::uint32_t> charmOffsets;
  std::vector<std::uint32_t> soulOffsets;
  std::vector<std::uint32_t> perkeoOffsets;
  std::vector<double> seedHashes;
  std::vector<double> tagSeedHashes;

  std::uint64_t processed = 0;
  while (processed < task.count) {
    const std::size_t count = static_cast<std::size_t>(
        std::min<std::uint64_t>(kChunkSize, task.count - processed));
    const std::uint64_t chunkStart = task.start + processed;

    collectOpeningTagCandidatesWithContext(
        tagContext, static_cast<long long>(chunkStart), count, charmOffsets);
    collectOpeningCharmSoulCandidatesWithContext(
        soulContext, static_cast<long long>(chunkStart), count, soulOffsets);
    collectOpeningCharmSoulCandidatesWithContext(
        perkeoContext, static_cast<long long>(chunkStart), count,
        perkeoOffsets);

    std::array<std::vector<std::uint8_t>, StageCount> flags;
    for (auto &stageFlags : flags) stageFlags.assign(count, 0);
    markOffsets(flags[Charm], charmOffsets);
    markOffsets(flags[CharmSoul], soulOffsets);
    markOffsets(flags[CharmSoulPerkeo], perkeoOffsets);

    for (std::uint32_t offset : soulOffsets) {
      const ExactFlags exact = classifyExact(chunkStart + offset);
      std::array<std::uint8_t, StageCount> exactStages{};
      setExactStages(exactStages, exact);
      for (int stage = CharmSoulJudgement; stage < StageCount; ++stage) {
        if (stage == CharmSoulPerkeo) continue;
        flags[stage][offset] = exactStages[stage];
      }
      // Differential guard: the production batch Perkeo label and the scalar
      // replay must agree for every sparse opening survivor.
      if (flags[CharmSoulPerkeo][offset] != exact.perkeo) {
        std::cerr << "Perkeo differential mismatch at seed id "
                  << (chunkStart + offset) << std::endl;
        std::abort();
      }
    }

    const bool hashChunk = task.collectHashes
                           && processed < kChunkSize * kHashSampleChunks;
    if (hashChunk) {
#if defined(BRAINSTORM_OPENING_BATCH_TESTING) && \
    defined(BRAINSTORM_OPENING_BATCH_AVX512)
      collectOpeningCharmSoulInitialHashesAvx512ForTesting(
          soulContext, static_cast<long long>(chunkStart), count,
          seedHashes, tagSeedHashes);
#elif defined(BRAINSTORM_OPENING_BATCH_TESTING) && \
      defined(BRAINSTORM_OPENING_BATCH_AVX2)
      collectOpeningCharmSoulInitialHashesAvx2ForTesting(
          soulContext, static_cast<long long>(chunkStart), count,
          seedHashes, tagSeedHashes);
#else
      seedHashes.clear();
      tagSeedHashes.clear();
#endif
    } else {
      seedHashes.clear();
      tagSeedHashes.clear();
    }

    Seed seed(static_cast<long long>(chunkStart));
    for (std::size_t offset = 0; offset < count; ++offset) {
      const std::uint64_t id = chunkStart + offset;
      const bool fullLength = seed.length == 8;
      EncodedFeatures features{};
      if (fullLength) {
        features = encodeFeatures(seed, id);
      } else {
        features.residue = static_cast<int>(id & (kResidueBuckets - 1));
      }
      addFeatures(stats.denominators, features, fullLength);
      stats.fullLengthSeeds += fullLength;

      if (!seedHashes.empty()) {
        const int seedBucket = bucket01(seedHashes[offset]);
        const int tagBucket = bucket01(tagSeedHashes[offset]);
        stats.denominators.seedHash[seedBucket]++;
        stats.denominators.tagSeedHash[tagBucket]++;
      }

      for (int stage = 0; stage < StageCount; ++stage) {
        if (!flags[stage][offset]) continue;
        stats.stageHits[stage]++;
        addFeatures(stats.hitsByFeature[stage], features, fullLength);
        if (!seedHashes.empty()) {
          stats.hitsByFeature[stage]
              .seedHash[bucket01(seedHashes[offset])]++;
          stats.hitsByFeature[stage]
              .tagSeedHash[bucket01(tagSeedHashes[offset])]++;
        }
        if (stage >= CharmSoulPerkeo) stats.hitIds[stage].push_back(id);
      }
      seed.next();
    }
    stats.seeds += count;
    updateLagAndBlockStats(stats, flags);
    processed += count;
  }

  destroyOpeningTagBatchContext(tagContext);
  destroyOpeningCharmSoulBatchContext(soulContext);
  destroyOpeningCharmSoulBatchContext(perkeoContext);
}

std::vector<std::uint64_t> parseStarts(const std::string &text) {
  std::vector<std::uint64_t> result;
  std::stringstream input(text);
  std::string field;
  while (std::getline(input, field, ',')) {
    if (!field.empty()) result.push_back(std::stoull(field));
  }
  return result;
}

void writeSummary(const std::filesystem::path &path,
                  const std::vector<std::uint64_t> &starts,
                  const std::vector<RangeStats> &ranges) {
  std::ofstream out(path);
  out << "range,start,seeds,full_length,stage,hits,rate\n";
  out << std::setprecision(17);
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    for (int stage = 0; stage < StageCount; ++stage) {
      out << range << ',' << starts[range] << ',' << ranges[range].seeds
          << ',' << ranges[range].fullLengthSeeds << ','
          << kStageNames[stage] << ',' << ranges[range].stageHits[stage]
          << ',' << static_cast<double>(ranges[range].stageHits[stage])
                         / static_cast<double>(ranges[range].seeds)
          << '\n';
    }
  }
}

void writeCharacterCounts(const std::filesystem::path &path,
                          const std::vector<RangeStats> &ranges) {
  std::ofstream out(path);
  out << "range,stage,position,character,denominator,hits\n";
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    for (int stage = 0; stage < StageCount; ++stage) {
      for (int pos = 0; pos < 8; ++pos) {
        for (int ch = 0; ch < 35; ++ch) {
          out << range << ',' << kStageNames[stage] << ',' << pos << ','
              << seedChars[ch] << ','
              << ranges[range].denominators.position[pos][ch] << ','
              << ranges[range].hitsByFeature[stage].position[pos][ch]
              << '\n';
        }
      }
    }
  }
}

template <class ArrayGetter>
void writeFeature(const std::filesystem::path &path,
                  const std::string &feature,
                  const std::vector<RangeStats> &ranges,
                  ArrayGetter getter) {
  std::ofstream out(path, std::ios::app);
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    const auto &denom = getter(ranges[range].denominators);
    for (int stage = 0; stage < StageCount; ++stage) {
      const auto &hits = getter(ranges[range].hitsByFeature[stage]);
      for (std::size_t bucket = 0; bucket < denom.size(); ++bucket) {
        if (denom[bucket] == 0 && hits[bucket] == 0) continue;
        out << range << ',' << kStageNames[stage] << ',' << feature << ','
            << bucket << ',' << denom[bucket] << ',' << hits[bucket]
            << '\n';
      }
    }
  }
}

void writeFeatures(const std::filesystem::path &path,
                   const std::vector<RangeStats> &ranges) {
  {
    std::ofstream out(path);
    out << "range,stage,feature,bucket,denominator,hits\n";
  }
  writeFeature(path, "prefix2", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.prefix2; });
  writeFeature(path, "suffix2", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.suffix2; });
  writeFeature(path, "outer2", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.outer2; });
  writeFeature(path, "prefix3", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.prefix3; });
  writeFeature(path, "suffix3", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.suffix3; });
  writeFeature(path, "id_mod_4096", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.residue; });
  writeFeature(path, "seed_hash_256", ranges,
               [](const FeatureCounts &x) -> const auto & { return x.seedHash; });
  writeFeature(path, "tag_seed_hash_256", ranges,
               [](const FeatureCounts &x) -> const auto & {
                 return x.tagSeedHash;
               });
}

void writeLags(const std::filesystem::path &path,
               const std::vector<RangeStats> &ranges) {
  std::ofstream out(path);
  out << "range,stage,lag,pairs,both\n";
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    for (int stage = 0; stage < StageCount; ++stage) {
      for (std::size_t lag = 0; lag < kLags.size(); ++lag) {
        out << range << ',' << kStageNames[stage] << ',' << kLags[lag]
            << ',' << ranges[range].lags[stage][lag].pairs << ','
            << ranges[range].lags[stage][lag].both << '\n';
      }
    }
  }
}

void writeBlocks(const std::filesystem::path &path,
                 const std::vector<RangeStats> &ranges) {
  std::ofstream out(path);
  out << "range,stage,block_size,blocks,zero_blocks,sum_hits,sum_squares,max_hits\n";
  out << std::setprecision(21);
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    for (int stage = 0; stage < StageCount; ++stage) {
      for (std::size_t block = 0; block < kBlockSizes.size(); ++block) {
        const auto &value = ranges[range].blocks[stage][block];
        out << range << ',' << kStageNames[stage] << ','
            << kBlockSizes[block] << ',' << value.blocks << ','
            << value.zeroBlocks << ',' << value.sum << ','
            << value.sumSquares << ',' << value.maxHits << '\n';
      }
    }
  }
}

void writeHits(const std::filesystem::path &path,
               const std::vector<RangeStats> &ranges) {
  std::ofstream out(path);
  out << "range,stage,id,seed\n";
  for (std::size_t range = 0; range < ranges.size(); ++range) {
    for (int stage = CharmSoulPerkeo; stage < StageCount; ++stage) {
      auto ids = ranges[range].hitIds[stage];
      std::sort(ids.begin(), ids.end());
      ids.erase(std::unique(ids.begin(), ids.end()), ids.end());
      for (std::uint64_t id : ids) {
        Seed seed(static_cast<long long>(id));
        out << range << ',' << kStageNames[stage] << ',' << id << ','
            << seed.tostring() << '\n';
      }
    }
  }
}

int parseThreadCount(const char *text) {
  if (std::string(text) == "auto") {
    const unsigned int detected = std::thread::hardware_concurrency();
    return static_cast<int>(std::clamp(detected == 0 ? 1u : detected,
                                       1u, 256u));
  }
  return std::clamp(std::stoi(text), 1, 256);
}

}  // namespace

int main(int argc, char **argv) {
  if (argc != 6) {
    std::cerr << "usage: structure_probe <output-dir> <count-per-range> "
                 "<threads|auto> <parts-per-range> <comma-separated-starts>\n";
    return 2;
  }
  const std::filesystem::path outputDir = argv[1];
  const std::uint64_t countPerRange = std::stoull(argv[2]);
  const int threadCount = parseThreadCount(argv[3]);
  const int partsPerRange = std::max(1, std::stoi(argv[4]));
  const std::vector<std::uint64_t> starts = parseStarts(argv[5]);
  if (starts.empty()) {
    std::cerr << "at least one range start is required\n";
    return 2;
  }
  for (std::uint64_t start : starts) {
    if (start >= static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)
        || countPerRange > static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)
        || start + countPerRange
               > static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)) {
      std::cerr << "range is outside the seed domain\n";
      return 2;
    }
  }
  std::filesystem::create_directories(outputDir);

  std::vector<Task> tasks;
  for (std::size_t range = 0; range < starts.size(); ++range) {
    const std::uint64_t basePart = countPerRange / partsPerRange;
    const std::uint64_t remainder = countPerRange % partsPerRange;
    std::uint64_t offset = 0;
    for (int part = 0; part < partsPerRange; ++part) {
      const std::uint64_t partCount = basePart + (part < remainder ? 1 : 0);
      tasks.push_back(Task{static_cast<int>(range), starts[range] + offset,
                           partCount, part == 0});
      offset += partCount;
    }
  }

  std::vector<RangeStats> partials(tasks.size());
  std::atomic<std::size_t> nextTask{0};
  std::atomic<std::uint64_t> finishedSeeds{0};
  std::mutex outputMutex;
  const auto begin = std::chrono::steady_clock::now();

  std::vector<std::thread> workers;
  workers.reserve(threadCount);
  for (int worker = 0; worker < threadCount; ++worker) {
    workers.emplace_back([&] {
      while (true) {
        const std::size_t taskIndex = nextTask.fetch_add(1);
        if (taskIndex >= tasks.size()) break;
        processTask(tasks[taskIndex], partials[taskIndex]);
        const std::uint64_t done =
            finishedSeeds.fetch_add(tasks[taskIndex].count)
            + tasks[taskIndex].count;
        const double seconds = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - begin).count();
        std::lock_guard<std::mutex> lock(outputMutex);
        std::cerr << "progress " << done << '/'
                  << countPerRange * starts.size() << " seeds, "
                  << std::fixed << std::setprecision(1)
                  << (done / seconds / 1.0e6) << " Mseed/s\n";
      }
    });
  }
  for (auto &worker : workers) worker.join();

  std::vector<RangeStats> ranges(starts.size());
  for (std::size_t task = 0; task < tasks.size(); ++task) {
    ranges[tasks[task].rangeIndex].add(partials[task]);
  }

  writeSummary(outputDir / "summary.csv", starts, ranges);
  writeCharacterCounts(outputDir / "characters.csv", ranges);
  writeFeatures(outputDir / "features.csv", ranges);
  writeLags(outputDir / "lags.csv", ranges);
  writeBlocks(outputDir / "blocks.csv", ranges);
  writeHits(outputDir / "hits.csv", ranges);

  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - begin).count();
  std::cout << "completed " << countPerRange * starts.size() << " seeds in "
            << std::fixed << std::setprecision(3) << seconds << " seconds ("
            << countPerRange * starts.size() / seconds / 1.0e6
            << " Mseed/s), backend="
            << openingCharmSoulBackendName(selectedOpeningCharmSoulBackend())
            << std::endl;
  return 0;
}
