#include "arbitrary_negative_batch.hpp"

#include "arbitrary_negative_batch_vector.hpp"
#include "rng.hpp"
#include "seed.hpp"
#include "util.hpp"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX2)
void collectArbitraryNegativeAvx2(
    void* workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets);
#endif

#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX512)
void collectArbitraryNegativeAvx512(
    void* workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets);
#endif

namespace {

using namespace BrainstormArbitraryNegativeBatchDetail;

struct ScalarNodeState {
  Seed& seed;
  double hashedSeed;
  const std::string& key;
  double state = 0.0;
  bool initialized = false;

  ScalarNodeState(Seed& seedRef, double hash, const std::string& streamKey)
      : seed(seedRef), hashedSeed(hash), key(streamKey) {}

  double nextSeed() {
    if (!initialized) {
      state = pseudohash_from(
          key, seed.pseudohash(static_cast<int>(key.size())));
      initialized = true;
    }
    state = round13(fractPositive(
        state * 1.72431234 + 2.134453429141));
    return (state + hashedSeed) * 0.5;
  }

  double nextRoll() { return lua_random_from_seed(nextSeed()); }
};

ArbitraryNegativeRarity rarityFromRoll(double roll) {
  if (roll > 0.95) {
    return ArbitraryNegativeRarity::Rare;
  }
  if (roll > 0.7) {
    return ArbitraryNegativeRarity::Uncommon;
  }
  return ArbitraryNegativeRarity::Common;
}

struct ScalarRequirementMatcher {
  const ArbitraryNegativeCriteria& criteria;
  std::array<bool, 1u << BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS>
      reachable{};

  explicit ScalarRequirementMatcher(
      const ArbitraryNegativeCriteria& criteriaRef)
      : criteria(criteriaRef) {
    reachable[0] = true;
  }

  void observe(unsigned int sourceBit, ArbitraryNegativeRarity rarity,
               bool negative) {
    if (!negative) {
      return;
    }
    const auto previous = reachable;
    const int subsetCount = 1 << criteria.requirementCount;
    for (int subset = 0; subset < subsetCount; ++subset) {
      if (!previous[static_cast<std::size_t>(subset)]) {
        continue;
      }
      for (int requirement = 0;
           requirement < criteria.requirementCount; ++requirement) {
        const int requirementBit = 1 << requirement;
        const auto& target =
            criteria.requirements[static_cast<std::size_t>(requirement)];
        if ((subset & requirementBit) == 0
            && target.rarity == rarity
            && requirementAcceptsSource(
                target, sourceBit, criteria.allowStartingPack)) {
          reachable[static_cast<std::size_t>(subset | requirementBit)] = true;
        }
      }
    }
  }

  bool complete() const {
    return reachable[static_cast<std::size_t>(
        (1 << criteria.requirementCount) - 1)];
  }
};

bool isBuffoonPack(Item item) {
  return item == Item::Buffoon_Pack
      || item == Item::Jumbo_Buffoon_Pack
      || item == Item::Mega_Buffoon_Pack;
}

int buffoonPackSize(Item item) {
  if (item == Item::Buffoon_Pack) {
    return 2;
  }
  if (item == Item::Jumbo_Buffoon_Pack
      || item == Item::Mega_Buffoon_Pack) {
    return 4;
  }
  return 0;
}

Item randomPackFromRoll(double roll) {
  const double poll = roll * PACKS[0].weight;
  int index = 1;
  double cumulative = 0.0;
  while (cumulative < poll) {
    cumulative += PACKS[static_cast<std::size_t>(index)].weight;
    ++index;
  }
  return PACKS[static_cast<std::size_t>(index - 1)].item;
}

class ScalarArbitraryNegativeEval {
 public:
  ScalarArbitraryNegativeEval(
      Seed& seedRef, const ArbitraryNegativeCriteria& criteriaRef)
      : seed(seedRef),
        criteria(criteriaRef),
        hashedSeed(seedRef.pseudohash(0)),
        matcher(criteriaRef) {}

  bool passes() {
    if (criteria.requirementCount <= 0) {
      return true;
    }

    if (anyRequirementAcceptsSource(criteria, soulSourceBit)) {
      ScalarNodeState edition(
          seed, hashedSeed, soulEditionKey());
      for (int selection = 0; selection < 2; ++selection) {
        matcher.observe(
            soulSourceBit, ArbitraryNegativeRarity::Legendary,
            edition.nextRoll() > negativeThreshold);
      }
    }
    if (anyRequirementAcceptsSource(criteria, judgementSourceBit)) {
      ScalarNodeState rarity(
          seed, hashedSeed, judgementRarityKey());
      ScalarNodeState edition(
          seed, hashedSeed, judgementEditionKey());
      matcher.observe(
          judgementSourceBit, rarityFromRoll(rarity.nextRoll()),
          edition.nextRoll() > negativeThreshold);
    }

    for (int ante = 1; ante <= criteria.maximumAnte; ++ante) {
      const unsigned int sourceBit = anteSourceBit(ante);
      if (!anyRequirementAcceptsSource(criteria, sourceBit)) {
        continue;
      }
      evaluateAnte(ante, sourceBit);
    }
    return matcher.complete();
  }

 private:
  Seed& seed;
  const ArbitraryNegativeCriteria& criteria;
  double hashedSeed;
  ScalarRequirementMatcher matcher;

  void evaluateAnte(int ante, unsigned int sourceBit) {
    const AnteKeys& keys = anteKeys()[static_cast<std::size_t>(ante - 1)];
    ScalarNodeState cardType(seed, hashedSeed, keys.cardType);
    ScalarNodeState shopRarity(seed, hashedSeed, keys.shopRarity);
    ScalarNodeState shopEdition(seed, hashedSeed, keys.shopEdition);
    ScalarNodeState packType(seed, hashedSeed, keys.packType);
    ScalarNodeState buffoonRarity(seed, hashedSeed, keys.buffoonRarity);
    ScalarNodeState buffoonEdition(seed, hashedSeed, keys.buffoonEdition);
    const int shops = ante == 1 ? criteria.anteOneShops : 3;

    for (int shop = 0; shop < shops; ++shop) {
      for (int card = 0; card < criteria.stockSize; ++card) {
        const bool joker = cardType.nextRoll()
            * shopTotalRate(criteria.shopRate) < 20.0;
        if (!joker) {
          continue;
        }
        matcher.observe(
            sourceBit, rarityFromRoll(shopRarity.nextRoll()),
            shopEdition.nextRoll() > negativeThreshold);
      }

      for (int displayed = 0; displayed < 2; ++displayed) {
        const Item pack = ante == 1 && shop == 0 && displayed == 0
            ? Item::Buffoon_Pack
            : randomPackFromRoll(packType.nextRoll());
        if (!isBuffoonPack(pack)) {
          continue;
        }
        const int size = buffoonPackSize(pack);
        for (int card = 0; card < size; ++card) {
          matcher.observe(
              sourceBit, rarityFromRoll(buffoonRarity.nextRoll()),
              buffoonEdition.nextRoll() > negativeThreshold);
        }
      }
    }
  }
};

ArbitraryNegativeCriteria sanitizeCriteria(
    const ArbitraryNegativeCriteria& criteria) {
  ArbitraryNegativeCriteria result;
  result.requirementCount = std::clamp(
      criteria.requirementCount, 0,
      static_cast<int>(BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS));
  result.maximumAnte = std::clamp(criteria.maximumAnte, 1, 8);
  result.anteOneShops = criteria.anteOneShops <= 1 ? 1 : 2;
  result.stockSize = criteria.stockSize >= 3 ? 3 : 2;
  result.shopRate = static_cast<ArbitraryNegativeShopRate>(std::clamp(
      static_cast<int>(criteria.shopRate), 0, 2));
  result.allowStartingPack = criteria.allowStartingPack;
  for (int index = 0; index < result.requirementCount; ++index) {
    result.requirements[static_cast<std::size_t>(index)].rarity =
        static_cast<ArbitraryNegativeRarity>(std::clamp(
            static_cast<int>(criteria.requirements[
                static_cast<std::size_t>(index)].rarity), 0, 3));
    result.requirements[static_cast<std::size_t>(index)].window =
        static_cast<ArbitraryNegativeWindow>(std::clamp(
            static_cast<int>(criteria.requirements[
                static_cast<std::size_t>(index)].window), 0, 12));
  }
  return result;
}

void collectScalar(
    const ArbitraryNegativeCriteria& criteria, long long startSeedId,
    std::size_t count, std::vector<std::uint32_t>& survivors) {
  survivors.clear();
  survivors.reserve(count / 100 + 8);
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    ScalarArbitraryNegativeEval eval(seed, criteria);
    if (eval.passes()) {
      survivors.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
}

bool cpuSupportsAvx2() {
#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX2) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx2");
#else
  return false;
#endif
}

bool cpuSupportsAvx512() {
#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX512) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx512f");
#else
  return false;
#endif
}

ArbitraryNegativeBackend automaticBackend() {
  static const ArbitraryNegativeBackend backend = [] {
    if (cpuSupportsAvx512()) {
      return ArbitraryNegativeBackend::Avx512;
    }
    if (cpuSupportsAvx2()) {
      return ArbitraryNegativeBackend::Avx2;
    }
    return ArbitraryNegativeBackend::Scalar;
  }();
  return backend;
}

bool equalsIgnoreCase(const char* value, const char* expected) {
  if (value == nullptr) {
    return false;
  }
  while (*value != '\0' && *expected != '\0') {
    char left = *value++;
    char right = *expected++;
    if (left >= 'A' && left <= 'Z') {
      left = static_cast<char>(left - 'A' + 'a');
    }
    if (right >= 'A' && right <= 'Z') {
      right = static_cast<char>(right - 'A' + 'a');
    }
    if (left != right) {
      return false;
    }
  }
  return *value == '\0' && *expected == '\0';
}

ArbitraryNegativeBackend environmentBackend() {
  const char* value = std::getenv(
      "BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_BACKEND");
  if (equalsIgnoreCase(value, "scalar")) {
    return ArbitraryNegativeBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx2")) {
    return cpuSupportsAvx2() ? ArbitraryNegativeBackend::Avx2
                             : ArbitraryNegativeBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx512")
      || equalsIgnoreCase(value, "avx-512")) {
    return cpuSupportsAvx512() ? ArbitraryNegativeBackend::Avx512
                               : ArbitraryNegativeBackend::Scalar;
  }
  return automaticBackend();
}

void collectOneChunk(
    void* context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivors,
    ArbitraryNegativeBackend backend) {
  auto& workspace = *static_cast<Workspace*>(context);
  switch (backend) {
#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX512)
    case ArbitraryNegativeBackend::Avx512:
      if (cpuSupportsAvx512()) {
        collectArbitraryNegativeAvx512(
            &workspace, startSeedId, count, survivors);
        return;
      }
      break;
#else
    case ArbitraryNegativeBackend::Avx512:
      break;
#endif
#if defined(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_AVX2)
    case ArbitraryNegativeBackend::Avx2:
      if (cpuSupportsAvx2()) {
        collectArbitraryNegativeAvx2(
            &workspace, startSeedId, count, survivors);
        return;
      }
      break;
#else
    case ArbitraryNegativeBackend::Avx2:
      break;
#endif
    case ArbitraryNegativeBackend::Auto:
    case ArbitraryNegativeBackend::Scalar:
      break;
  }
  collectScalar(workspace.criteria, startSeedId, count, survivors);
}

void collectAllWithContext(
    void* context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivors,
    ArbitraryNegativeBackend backend) {
  assert(count <= std::numeric_limits<std::uint32_t>::max());
  if (backend == ArbitraryNegativeBackend::Auto) {
    backend = environmentBackend();
  }
  if (count <= preferredChunkSize) {
    collectOneChunk(
        context, normalizeSeedId(startSeedId), count, survivors, backend);
    return;
  }

  auto& workspace = *static_cast<Workspace*>(context);
  survivors.clear();
  std::size_t processed = 0;
  while (processed < count) {
    const std::size_t chunkCount =
        std::min(preferredChunkSize, count - processed);
    const long long chunkStart = normalizeSeedId(
        normalizeSeedId(startSeedId) + static_cast<long long>(processed));
    collectOneChunk(
        context, chunkStart, chunkCount,
        workspace.localSurvivors, backend);
    for (std::uint32_t offset : workspace.localSurvivors) {
      survivors.push_back(
          static_cast<std::uint32_t>(processed) + offset);
    }
    processed += chunkCount;
  }
}

}  // namespace

ArbitraryNegativeBackend selectedArbitraryNegativeBackend() {
  return environmentBackend();
}

bool arbitraryNegativeVectorBackendAvailable() {
  return selectedArbitraryNegativeBackend()
      != ArbitraryNegativeBackend::Scalar;
}

bool arbitraryNegativeBackendAvailable(ArbitraryNegativeBackend backend) {
  switch (backend) {
    case ArbitraryNegativeBackend::Auto:
    case ArbitraryNegativeBackend::Scalar:
      return true;
    case ArbitraryNegativeBackend::Avx2:
      return cpuSupportsAvx2();
    case ArbitraryNegativeBackend::Avx512:
      return cpuSupportsAvx512();
  }
  return false;
}

const char* arbitraryNegativeBackendName(ArbitraryNegativeBackend backend) {
  switch (backend) {
    case ArbitraryNegativeBackend::Auto: return "auto";
    case ArbitraryNegativeBackend::Scalar: return "scalar";
    case ArbitraryNegativeBackend::Avx2: return "avx2";
    case ArbitraryNegativeBackend::Avx512: return "avx512";
  }
  return "unknown";
}

std::uint64_t encodeArbitraryNegativeCriteria(
    const ArbitraryNegativeCriteria& criteria) {
  const ArbitraryNegativeCriteria sanitized = sanitizeCriteria(criteria);
  std::uint64_t result =
      static_cast<std::uint64_t>(sanitized.requirementCount)
      | (static_cast<std::uint64_t>(sanitized.maximumAnte - 1) << 3u)
      | (static_cast<std::uint64_t>(sanitized.anteOneShops == 2) << 6u)
      | (static_cast<std::uint64_t>(sanitized.stockSize == 3) << 7u)
      | (static_cast<std::uint64_t>(sanitized.shopRate) << 8u)
      | (static_cast<std::uint64_t>(sanitized.allowStartingPack) << 10u);
  for (int index = 0; index < sanitized.requirementCount; ++index) {
    const auto& requirement =
        sanitized.requirements[static_cast<std::size_t>(index)];
    const std::uint64_t packed =
        static_cast<std::uint64_t>(requirement.rarity)
        | (static_cast<std::uint64_t>(requirement.window) << 2u);
    result |= packed << static_cast<unsigned int>(11 + index * 6);
  }
  return result;
}

ArbitraryNegativeCriteria decodeArbitraryNegativeCriteria(
    std::uint64_t configuration) {
  ArbitraryNegativeCriteria result;
  result.requirementCount = std::clamp(
      static_cast<int>(configuration & 0x7u), 0,
      static_cast<int>(BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS));
  result.maximumAnte = 1
      + static_cast<int>((configuration >> 3u) & 0x7u);
  result.anteOneShops = ((configuration >> 6u) & 0x1u) != 0 ? 2 : 1;
  result.stockSize = ((configuration >> 7u) & 0x1u) != 0 ? 3 : 2;
  const int rate = static_cast<int>((configuration >> 8u) & 0x3u);
  result.shopRate = rate == static_cast<int>(
          ArbitraryNegativeShopRate::Ghost)
      ? ArbitraryNegativeShopRate::Ghost
      : rate == static_cast<int>(ArbitraryNegativeShopRate::Zodiac)
      ? ArbitraryNegativeShopRate::Zodiac
      : ArbitraryNegativeShopRate::Ordinary;
  result.allowStartingPack = ((configuration >> 10u) & 0x1u) != 0;
  for (int index = 0; index < result.requirementCount; ++index) {
    const std::uint64_t packed =
        (configuration >> static_cast<unsigned int>(11 + index * 6))
        & 0x3fu;
    const int rarity = static_cast<int>(packed & 0x3u);
    const int window = static_cast<int>((packed >> 2u) & 0xfu);
    result.requirements[static_cast<std::size_t>(index)].rarity =
        static_cast<ArbitraryNegativeRarity>(std::clamp(rarity, 0, 3));
    result.requirements[static_cast<std::size_t>(index)].window =
        static_cast<ArbitraryNegativeWindow>(std::clamp(window, 0, 12));
  }
  return sanitizeCriteria(result);
}

void* createArbitraryNegativeBatchContext(std::uint64_t configuration) {
  auto* workspace = new Workspace();
  workspace->criteria = decodeArbitraryNegativeCriteria(configuration);
  return workspace;
}

void destroyArbitraryNegativeBatchContext(void* context) {
  delete static_cast<Workspace*>(context);
}

void collectArbitraryNegativeCandidatesWithContext(
    void* context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets) {
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets,
      selectedArbitraryNegativeBackend());
}

void collectArbitraryNegativeCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets,
    const ArbitraryNegativeCriteria& criteria) {
  void* context = createArbitraryNegativeBatchContext(
      encodeArbitraryNegativeCriteria(criteria));
  collectArbitraryNegativeCandidatesWithContext(
      context, startSeedId, count, survivorOffsets);
  destroyArbitraryNegativeBatchContext(context);
}

void collectArbitraryNegativeCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets,
    const ArbitraryNegativeCriteria& criteria,
    ArbitraryNegativeBackend backend) {
  void* context = createArbitraryNegativeBatchContext(
      encodeArbitraryNegativeCriteria(criteria));
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets, backend);
  destroyArbitraryNegativeBatchContext(context);
}

bool passesArbitraryNegativeCriteria(
    Seed& seed, const ArbitraryNegativeCriteria& criteria) {
  const ArbitraryNegativeCriteria sanitized = sanitizeCriteria(criteria);
  ScalarArbitraryNegativeEval eval(seed, sanitized);
  return eval.passes();
}
